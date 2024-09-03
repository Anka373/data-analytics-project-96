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
    group by 2, 3, 4, 5
),

ad_total_spent as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
)

select
    t2.visit_date,
    t2.utm_source,
    t2.utm_medium,
    t2.utm_campaign,
    t2.visitors_count,
    ads.total_cost,
    t2.leads_count,
    t2.purchases_count,
    t2.revenue
from tab2 as t2
left join ad_total_spent as ads
    on
        t2.visit_date = ads.visit_date
        and t2.utm_source = ads.utm_source
        and t2.utm_medium = ads.utm_medium
        and t2.utm_campaign = ads.utm_campaign
order by
    9 desc nulls last,
    1, 5 desc, 2, 3, 4
limit 15;
