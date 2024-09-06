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


