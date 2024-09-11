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
with tab as (
    select
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count
    from sessions
    group by visit_date
    order by visit_date
)

select
    visit_date,
    sum(visitors_count) as visitors_count
from tab
group by visit_date;

-- каналы, приводящие пользователей (по дням)
with tab as (
    select
        source,
        date(visit_date) as visit_date
    from sessions
)

select
    visit_date,
    source,
    count(source) as source_count
from tab
group by visit_date, source
order by visit_date asc, source_count desc;

-- каналы, приводящие пользователей (по неделям)
with tab as (
    select
        source,
        date(visit_date) as visit_date
    from sessions
)

select
    source,
    to_char(date_trunc('week', visit_date), 'W') as visit_week,
    count(source) as source_count
from tab
group by visit_week, source
order by visit_week asc, source_count desc;

-- каналы, приводящие пользователей (за весь месяц)
with tab as (
    select
        source,
        date(visit_date) as visit_date
    from sessions
)

select
    source,
    to_char(date_trunc('month', visit_date), 'yyyy-mm') as visit_week,
    count(source) as source_count
from tab
group by visit_week, source
order by visit_week asc, source_count desc;

--количество посетителей, лидов и покупателей
select
    count(distinct s.visitor_id) as visitors_count,
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
        count(distinct s.visitor_id) as visitors_count,
        count(l.lead_id) as leads_count,
        sum(case when l.closing_reason = 'Успешная продажа' then 1 else 0 end)
        as clients
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
)

select
    round(leads_count * 100.0 / visitors_count, 2) as first_conversion,
    round(clients * 100.0 / leads_count, 2) as second_conversion
from tab;

--траты на рекламу
with vk as (
    select
        daily_spent,
        date(campaign_date) as pay_day
    from vk_ads
    order by date
),

ya as (
    select
        daily_spent,
        date(campaign_date) as pay_day
    from ya_ads
    order by date
)

select
    'vk' as source,
    date,
    sum(daily_spent) as spend
from vk
group by source, date
union all
select
    'ya' as source,
    date,
    sum(daily_spent) as spend
from ya
group by source, date
order by source, date;

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
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

tab2 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(distinct lead_id) as leads_count,
        count(status_id) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by 1, 2, 3, 4
),

ad_total_spent as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from vk_ads
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from ya_ads
),

tab3 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ad_total_spent
    group by 1, 2, 3, 4
),

tab4 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
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
        utm_medium,
        utm_campaign,
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
        utm_medium,
        utm_campaign,
        sum(coalesce(visitors_count, 0)) as visitors_count,
        sum(coalesce(leads_count, 0)) as leads_count,
        sum(coalesce(purchases_count, 0)) as purchases_count,
        sum(coalesce(revenue, 0)) as revenue,
        sum(coalesce(total_cost, 0)) as total_cost
    from tab4
    where utm_source = 'yandex'
    group by 1, 2, 3
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
from tab5
order by roi desc;

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
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

tab2 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(distinct lead_id) as leads_count,
        count(status_id) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by 1, 2, 3, 4
),

ad_total_spent as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from vk_ads
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from ya_ads
),

tab3 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ad_total_spent
    group by 1, 2, 3, 4
),

tab4 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
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
        utm_medium,
        utm_campaign,
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
        utm_medium,
        utm_campaign,
        sum(coalesce(visitors_count, 0)) as visitors_count,
        sum(coalesce(leads_count, 0)) as leads_count,
        sum(coalesce(purchases_count, 0)) as purchases_count,
        sum(coalesce(revenue, 0)) as revenue,
        sum(coalesce(total_cost, 0)) as total_cost
    from tab4
    where utm_source = 'vk'
    group by 1, 2, 3
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
from tab5
order by roi desc;
