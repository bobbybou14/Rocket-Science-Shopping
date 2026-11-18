begin;

alter table public.receipts
  add column if not exists shopping_trip_id uuid
  references public.shopping_trips(id) on delete set null;

create index if not exists receipts_shopping_trip_id_idx
  on public.receipts(shopping_trip_id);

-- Existing releases did not have to update shopping trips in place.
drop policy if exists receipt_merge_update_own_trip on public.shopping_trips;
create policy receipt_merge_update_own_trip on public.shopping_trips
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.save_receipt_shopping_trip(
  p_receipt_id uuid,
  p_trip jsonb,
  p_items jsonb,
  p_receipt_items jsonb,
  p_merge_trip_id uuid default null,
  p_day_start timestamptz default null,
  p_day_end timestamptz default null
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_user uuid := auth.uid();
  v_receipt public.receipts%rowtype;
  v_trip public.shopping_trips%rowtype;
  v_target public.shopping_trips%rowtype;
  v_trip_id uuid;
begin
  if v_user is null then
    raise exception 'Sign in before saving a receipt.';
  end if;

  -- Serialize retries of this receipt before changing any rows.
  select * into v_receipt from public.receipts
    where id = p_receipt_id and user_id = v_user for update;
  if not found then
    raise exception 'The receipt was not found or does not belong to you.';
  end if;
  if v_receipt.shopping_trip_id is not null then
    perform 1 from public.shopping_trips
      where id = v_receipt.shopping_trip_id and user_id = v_user;
    if not found then
      raise exception 'The linked shopping trip is unavailable.';
    end if;
    return jsonb_build_object(
      'trip_id', v_receipt.shopping_trip_id, 'already_saved', true
    );
  end if;

  if jsonb_typeof(p_items) is distinct from 'array'
      or jsonb_typeof(p_receipt_items) is distinct from 'array' then
    raise exception 'Receipt items must be arrays.';
  end if;
  if jsonb_array_length(p_items) = 0
      or jsonb_array_length(p_items) <> jsonb_array_length(p_receipt_items) then
    raise exception 'The receipt item snapshot is incomplete.';
  end if;

  select * into v_trip
    from jsonb_populate_record(null::public.shopping_trips, p_trip);
  if v_trip.purchase_date is null or v_trip.store_name is null
      or v_trip.processing_status not in ('verified', 'pending_review') then
    raise exception 'The receipt trip details are incomplete.';
  end if;
  if v_receipt.store_id is not null
      and v_trip.store_id is distinct from v_receipt.store_id then
    raise exception 'The selected store differs from this receipt.';
  end if;
  if exists (
    select 1 from jsonb_each_text(p_trip) e
    where e.key in ('subtotal','tax','total')
      and e.value !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
  ) or v_trip.subtotal is null or v_trip.tax is null or v_trip.total is null then
    raise exception 'Receipt amounts must be finite numbers.';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) e,
      lateral jsonb_populate_record(null::public.shopping_trip_items, e) i
    where i.quantity is null or i.quantity <= 0
      or i.quantity in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or i.unit_price is null
      or i.unit_price in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or i.line_total is null
      or i.line_total in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or (v_trip.processing_status = 'verified' and i.requires_review is distinct from false)
  ) then
    raise exception 'Review the receipt item amounts before saving.';
  end if;

  if p_merge_trip_id is not null then
    select * into v_target from public.shopping_trips
      where id = p_merge_trip_id and user_id = v_user for update;
    if not found then
      raise exception 'The selected trip was not found or does not belong to you.';
    end if;
    if p_day_start is null or p_day_end is null
        or p_day_end <= p_day_start
        or p_day_end - p_day_start > interval '27 hours'
        or v_trip.purchase_date < p_day_start or v_trip.purchase_date >= p_day_end
        or (
          (v_target.purchase_date < p_day_start or v_target.purchase_date >= p_day_end)
          and not (
            v_target.source = 'live_shopping' and v_target.store_id is null
            and (v_target.purchase_date at time zone 'UTC')::date
                = coalesce((p_trip->>'purchase_day')::date, '-infinity'::date)
          )
        ) then
      raise exception 'The selected trip is from a different purchase date.';
    end if;
    if v_target.store_id is not null and v_trip.store_id is not null then
      if v_target.store_id <> v_trip.store_id then
        raise exception 'The selected trip is from a different store branch.';
      end if;
    else
      if regexp_replace(lower(v_target.store_name), '[^a-z0-9]', '', 'g') = ''
          or regexp_replace(lower(v_target.store_name), '[^a-z0-9]', '', 'g')
              <> regexp_replace(lower(v_trip.store_name), '[^a-z0-9]', '', 'g')
          or (coalesce(v_target.city, '') <> '' and coalesce(v_trip.city, '') <> ''
              and regexp_replace(lower(v_target.city), '[^a-z0-9]', '', 'g')
                  <> regexp_replace(lower(v_trip.city), '[^a-z0-9]', '', 'g')) then
        raise exception 'The selected trip does not match this store.';
      end if;
    end if;
    v_trip_id := v_target.id;
    update public.shopping_trips set
      store_id = v_trip.store_id, store_name = v_trip.store_name,
      city = v_trip.city, province = v_trip.province,
      purchase_date = v_trip.purchase_date,
      subtotal = v_trip.subtotal, tax = v_trip.tax, total = v_trip.total,
      source = 'receipt', processing_status = v_trip.processing_status
      where id = v_trip_id and user_id = v_user;
    if not found then
      raise exception 'The selected trip could not be updated.';
    end if;
    delete from public.shopping_trip_items where shopping_trip_id = v_trip_id;
    -- A denied child DELETE must never turn replacement into an append.
    if exists (select 1 from public.shopping_trip_items where shopping_trip_id = v_trip_id) then
      raise exception 'The existing trip items could not be replaced.';
    end if;
  else
    insert into public.shopping_trips (
      user_id, store_id, store_name, city, province, purchase_date,
      subtotal, tax, total, source, processing_status
    ) values (
      v_user, v_trip.store_id, v_trip.store_name, v_trip.city, v_trip.province,
      v_trip.purchase_date, v_trip.subtotal, v_trip.tax, v_trip.total,
      'receipt', v_trip.processing_status
    ) returning id into v_trip_id;
  end if;

  insert into public.shopping_trip_items (
    shopping_trip_id, raw_receipt_name, barcode, quantity, unit_price,
    line_total, confidence_score, requires_review
  )
  select v_trip_id, i.raw_receipt_name, i.barcode, i.quantity,
    i.unit_price, i.line_total, i.confidence_score, i.requires_review
  from jsonb_array_elements(p_items) e,
    lateral jsonb_populate_record(null::public.shopping_trip_items, e) i;

  delete from public.receipt_items where receipt_id = p_receipt_id;
  if exists (select 1 from public.receipt_items where receipt_id = p_receipt_id) then
    raise exception 'The receipt snapshot could not be replaced.';
  end if;
  insert into public.receipt_items (
    receipt_id, barcode, product_name, quantity, unit_price, total_price,
    tax_amount, matched_product, confidence_score
  )
  select p_receipt_id, i.barcode, i.product_name, i.quantity, i.unit_price,
    i.total_price, i.tax_amount, i.matched_product, i.confidence_score
  from jsonb_array_elements(p_receipt_items) e,
    lateral jsonb_populate_record(null::public.receipt_items, e) i;

  update public.receipts set
    shopping_trip_id = v_trip_id, purchase_date = v_trip.purchase_date::date,
    subtotal = v_trip.subtotal, tax = v_trip.tax, total = v_trip.total,
    processing_status = 'pending_review',
    notes = 'Shopping trip: ' || v_trip_id::text || '. Receipt items saved.'
  where id = p_receipt_id and user_id = v_user;
  if not found then
    raise exception 'The receipt could not be linked to the saved trip.';
  end if;

  return jsonb_build_object('trip_id', v_trip_id, 'already_saved', false);
end;
$function$;

revoke all on function public.save_receipt_shopping_trip(
  uuid,jsonb,jsonb,jsonb,uuid,timestamptz,timestamptz
) from public, anon;
grant execute on function public.save_receipt_shopping_trip(
  uuid,jsonb,jsonb,jsonb,uuid,timestamptz,timestamptz
) to authenticated;

commit;
