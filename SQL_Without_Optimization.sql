-- find latest salary for each employee
with CTE as(select *, rank() over(partition by employee_id order by change_date desc) as latest_salary_rank,
            rank() over(partition by employee_id order by change_date Asc) as first_salary_rank
from salary_history),
Latest_salary_CTE as (
select employee_id,salary as latest_Salary
from CTE
where latest_salary_rank = 1),

-- calculate total number of promotions each employee has received
Promotions_CTE as (select employee_id,count(*) as promotion_count
from CTE
where promotion = 'Yes'
group by employee_id),

-- dertermine the maximum salary hike percentage between any two consecutive salary changes for each employee
Previous_Salary_cte as (select *, 
                        lead(salary,1) over (partition by employee_id order by change_date desc) as previous_Salary,
salary as Current_Salary,
                        lead(change_date,1) over (partition by employee_id order by change_date desc) as previous_Change_date
from CTE),
Salary_Growth_CTE as (
select employee_id, max(round(100.0*(salary-previous_Salary)/previous_Salary,2)) as Employee_Max_Salary_Hike
from Previous_Salary_cte
group by employee_id
),

-- find employees whos salary has never decreased overtime
Salary_NeverDecreased as (
select DISTINCT employee_id, 'N' as never_decreased
  from Previous_Salary_cte
  where Current_Salary < previous_Salary

),

-- Avg months between changes
Avg_months_cte as (SELECT employee_id,
   avg((CAST(strftime('%Y', change_date) AS INT) - CAST(strftime('%Y', previous_Change_date) AS INT)) * 12 +
   (CAST(strftime('%m', change_date) AS INT) - CAST(strftime('%m', previous_Change_date) AS INT)))
   AS Avg_diff_months
from Previous_Salary_cte
group by employee_id),

-- rank employees by their salary growth rate from first to last recorderd salary), breaking ties by earliest join date
growth_rate_cte as (select employee_id, round(100.0*(max(case when latest_salary_rank = 1 then salary end)-
max(case when first_salary_rank = 1 then salary end))/max(case when first_salary_rank = 1 then salary end),2) as emp_growth_rate,
                   min(change_date) as joining_date
from cte
group by employee_id),

Salary_growth_rank_cte as (
select *,rank() over (order by emp_growth_rate desc,joining_date asc) as growth_rate_rank
from growth_rate_cte)

--- combine all metrix and show in single table output

select E.employee_id,E.name,LS.latest_Salary,IFNULL(P.promotion_count,0) as No_of_Promotions,SG.Employee_Max_Salary_Hike,
ifnull(SD.never_decreased,'Y'),AM.Avg_diff_months,GR.growth_rate_rank
from employees as E
left join Latest_salary_CTE as LS on LS.employee_id = E.employee_id
left join Promotions_CTE as P on P.employee_id = E.employee_id
left join Salary_Growth_CTE as SG on SG.employee_id = E.employee_id
left join Salary_NeverDecreased as SD on SD.employee_id = E.employee_id
left join Avg_months_cte as AM on AM.employee_id = E.employee_id
left join Salary_growth_rank_cte as GR on GR.employee_id = E.employee_id