with last_date as (
    select
        visitor_id,
        max(visit_date) as visit_date
    from sessions
    group by visitor_id
)

select
    ld.visitor_id,
    ld.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from sessions as s
inner join last_date as ld on s.visitor_id = ld.visitor_id
left join leads as l on ld.visitor_id = l.visitor_id
where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
order by
    l.amount desc nulls last, ld.visit_date asc,
    utm_source asc, utm_medium asc, utm_campaign asc
limit 10;
