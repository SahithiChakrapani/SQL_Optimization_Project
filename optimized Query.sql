-- find latest salary for each employee
with CTE as(select *, rank() over(partition by employee_id order by change_date desc) as latest_salary_rank,
            rank() over(partition by employee_id order by change_date Asc) as first_salary_rank,
            lead(salary,1) over (partition by employee_id order by change_date desc) as previous_Salary,
            lead(change_date,1) over (partition by employee_id order by change_date desc) as previous_Change_date
from salary_history),


-- rank employees by their salary growth rate from first to last recorderd salary), breaking ties by earliest join date
growth_rate_cte as (select employee_id, round(100.0*(max(case when latest_salary_rank = 1 then salary end)-
max(case when first_salary_rank = 1 then salary end))/max(case when first_salary_rank = 1 then salary end),2) as emp_growth_rate,
                   min(change_date) as joining_date
from cte
group by employee_id)


-- optimize code , reduced CTEs
-- latest salary cte
select A.*,B.emp_latest_salary,B.emp_total_promotions,B.Employee_Max_Salary_Hike,B.salary_never_decreased,B.Avg_diff_months,B.growth_rate_rank
from 
(select employee_id,name 
from employees) as A

left join 

(select CTE.employee_id, max(case when latest_salary_rank = 1 then salary end) as emp_latest_salary,
sum(case when promotion = 'Yes' then 1 else 0 end) as emp_total_promotions,
max(round(100.0*(salary-previous_Salary)/previous_Salary,2)) as Employee_Max_Salary_Hike,
ifnull(max(case when salary < previous_Salary then 'N' end),'Y') as  salary_never_decreased,
   avg((CAST(strftime('%Y', change_date) AS INT) - CAST(strftime('%Y', previous_Change_date) AS INT)) * 12 +
   (CAST(strftime('%m', change_date) AS INT) - CAST(strftime('%m', previous_Change_date) AS INT)))
   AS Avg_diff_months,
   rank() over (order by emp_growth_rate desc,joining_date asc) as growth_rate_rank
from CTE
join growth_rate_cte GR on CTE.employee_id = GR.employee_id
group by CTE.employee_id) as B
on A.employee_id = B.employee_id

--select * from employees



