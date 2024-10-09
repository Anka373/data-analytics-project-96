--подсчет общего числа визитов
select count(visitor_id) as total_visits
from sessions;

--подсчет количества уникальных пользователей
select count(distinct visitor_id) as total_visits
from sessions;

--количество лидов
select count(visitor_id) as leads_count
from leads;

--количество продаж
select count(visitor_id) as leads_count
from leads
where closing_reason = 'Успешная продажа';

--посещаемость по дням
select
    date(visit_date) as visit_date,
    count(visitor_id) as visitors_count
from sessions
group by 1
order by 1;

-- каналы, приводящие пользователей (по дням)
with tab as (
    select
        s.visitor_id,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        date(s.visit_date) as visit_date,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    from tab
    where rn = 1
    order by
        8 desc nulls last,
        2 asc,
        3 asc,
        4 asc,
        5 asc
)

select
    visit_date,
    utm_source,
    count(utm_source) as source_count
from tab2
group by 1, 2
order by 1 asc, 3 desc;

-- каналы, приводящие пользователей (по неделям)
select
    source,
    to_char(date_trunc('week', visit_date), 'W') as visit_week,
    count(source) as source_count
from sessions
group by 2, 1
order by 2 asc, 3 desc;

--второй вариант
select
    source,
    case
        when date(visit_date) between '2023-06-01' and '2023-06-04' then 1
        when date(visit_date) between '2023-06-05' and '2023-06-11' then 2
        when date(visit_date) between '2023-06-12' and '2023-06-18' then 3
        when date(visit_date) between '2023-06-19' and '2023-06-25' then 4
        when date(visit_date) between '2023-06-26' and '2023-06-30' then 5
    end as visit_date,
    count(source) as source_count
from sessions
group by 1, 2
order by 2

--количество посетителей, лидов и покупателей
select
    'total' as category,
    count(s.visitor_id) as visitors_count,
    count(l.lead_id) as leads_count,
    sum(case when l.closing_reason = 'Успешная продажа' then 1 else 0 end)
    as clients
from sessions as s
left join
    leads as l
    on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at;

--конверсия в процентах
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    from tab
    where rn = 1
    order by
        8 desc nulls last,
        2 asc,
        3 asc,
        4 asc,
        5 asc
),

tab3 as (
    select
        count(distinct t2.visitor_id) as visitors_count,
        count(distinct t2.lead_id) as leads_count,
        sum(case when t2.closing_reason = 'Успешная продажа' then 1 else 0 end)
        as clients
    from tab2 as t2
)

select
    round(leads_count * 100.0 / visitors_count, 2) as first_conversion,
    round(clients * 100.0 / leads_count, 2) as second_conversion
from tab3;

--траты на рекламу
with vk as (
    select
        daily_spent,
        date(campaign_date) as pay_day
    from vk_ads
),

ya as (
    select
        daily_spent,
        date(campaign_date) as pay_day
    from ya_ads
)

select
    'vk' as source,
    pay_day,
    sum(daily_spent) as spend
from vk
group by 1, 2
union all
select
    'ya' as source,
    pay_day,
    sum(daily_spent) as spend
from ya
group by 1, 2
order by 1, 2;

--затраты на рекламу по каждому каналу
select
    'vk' as source,
    sum(daily_spent) as spent
from vk_ads
union
select
    'ya' as source,
    sum(daily_spent) as spent
from ya_ads;

--затраты на рекламу, выручка и прибыль по каждому каналу
with spending as (
    select
        'vk' as source,
        sum(daily_spent) as spent
    from vk_ads
    union
    select
        'ya' as source,
        sum(daily_spent) as spent
    from ya_ads
),

total_amount as (
    select
        'vk' as source,
        sum(l.amount) as revenue
    from leads as l
    inner join sessions as s on l.visitor_id = s.visitor_id and source = 'vk'
    union
    select
        'ya' as source,
        sum(l.amount) as revenue
    from leads as l
    inner join
        sessions as s
        on l.visitor_id = s.visitor_id and source = 'yandex'
)

select
    s.source,
    s.spent,
    a.revenue,
    (a.revenue - s.spent) as profit
from spending as s
inner join total_amount as a on s.source = a.source;

--ключевые метрики яндекса
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.source as utm_source,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select
        utm_source,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(distinct lead_id) as leads_count,
        count(status_id) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by 1, 2
),

ad_total_spent as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        daily_spent
    from vk_ads
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        daily_spent
    from ya_ads
),

tab3 as (
    select
        visit_date,
        utm_source,
        sum(daily_spent) as total_cost
    from ad_total_spent
    group by 1, 2
),

tab4 as (
    select
        visit_date,
        utm_source,
        null as visitors_count,
        null as leads_count,
        null as purchases_count,
        null as revenue,
        total_cost
    from tab3
    union all
    select
        visit_date,
        utm_source,
        visitors_count,
        leads_count,
        purchases_count,
        revenue,
        null as total_cost
    from tab2
),

tab5 as (
    select
        utm_source,
        sum(coalesce(visitors_count, 0)) as visitors_count,
        sum(coalesce(leads_count, 0)) as leads_count,
        sum(coalesce(purchases_count, 0)) as purchases_count,
        sum(coalesce(revenue, 0)) as revenue,
        sum(coalesce(total_cost, 0)) as total_cost
    from tab4
    where utm_source = 'yandex'
)

select
    *,
    round(total_cost / visitors_count) as cpu,
    round(
        total_cost / (case when leads_count = 0 then 1 else leads_count end)
    ) as cpl,
    round(
        total_cost
        / (case when purchases_count = 0 then 1 else purchases_count end)
    ) as cppu,
    round(
        (revenue - total_cost)
        * 100.0
        / (case when total_cost = 0 then 1 else total_cost end)
    ) as roi
from tab5;

--ключевые метрики вк
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.source as utm_source,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select
        utm_source,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(distinct lead_id) as leads_count,
        count(status_id) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by 1, 2
),

ad_total_spent as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        daily_spent
    from vk_ads
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        daily_spent
    from ya_ads
),

tab3 as (
    select
        visit_date,
        utm_source,
        sum(daily_spent) as total_cost
    from ad_total_spent
    group by 1, 2
),

tab4 as (
    select
        visit_date,
        utm_source,
        null as visitors_count,
        null as leads_count,
        null as purchases_count,
        null as revenue,
        total_cost
    from tab3
    union all
    select
        visit_date,
        utm_source,
        visitors_count,
        leads_count,
        purchases_count,
        revenue,
        null as total_cost
    from tab2
),

tab5 as (
    select
        utm_source,
        sum(coalesce(visitors_count, 0)) as visitors_count,
        sum(coalesce(leads_count, 0)) as leads_count,
        sum(coalesce(purchases_count, 0)) as purchases_count,
        sum(coalesce(revenue, 0)) as revenue,
        sum(coalesce(total_cost, 0)) as total_cost
    from tab4
    where utm_source = 'vk'
    group by 1
)

select
    *,
    round(total_cost / visitors_count) as cpu,
    round(
        total_cost / (case when leads_count = 0 then 1 else leads_count end)
    ) as cpl,
    round(
        total_cost
        / (case when purchases_count = 0 then 1 else purchases_count end)
    ) as cppu,
    round(
        (revenue - total_cost)
        * 100.0
        / (case when total_cost = 0 then 1 else total_cost end)
    ) as roi
from tab5;
