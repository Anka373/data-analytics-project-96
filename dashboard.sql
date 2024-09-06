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


