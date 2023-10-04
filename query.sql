-- Consolidates employee details and the maximum to_date from the salaries table into a view, reflecting the end (termination) date of each employee, as well as the associated
-- department and title for each employee at the time of hire / termination.
CREATE VIEW emp_details AS
SELECT 
    e.emp_no,
    e.birth_date,
    e.first_name,
    e.last_name,
    e.gender,
    e.hire_date,
    (SELECT MAX(s.to_date) FROM salaries s WHERE s.emp_no = e.emp_no) AS end_date,
    (SELECT d.dept_no FROM dept_emp d WHERE d.emp_no = e.emp_no ORDER BY d.from_date ASC LIMIT 1) AS dept_no_hire,
    (SELECT t.title FROM titles t WHERE t.emp_no = e.emp_no ORDER BY t.from_date ASC LIMIT 1) AS title_hire,
    (SELECT d.dept_no FROM dept_emp d WHERE d.emp_no = e.emp_no ORDER BY d.from_date DESC LIMIT 1) AS dept_no_end,
    (SELECT t.title FROM titles t WHERE t.emp_no = e.emp_no ORDER BY t.from_date DESC LIMIT 1) AS title_end
FROM employees e;

-----------------------------------------------

-- These queries are used to identify employees for whom the hire_date in the emp_details table does not match their earliest from_date in the titles, dept_emp, and salaries tables. 
-- For such employees, these queries also indicate whether the hire_date is 'Earlier' or 'Later' than the earliest from_date.
-- The results show that for several employees, identified by emp_no, their hire_date is earlier than the earliest 'from_date' in their title, department, and salary records.
-- This could either indicate missing title / dept / salary records between the two dates, or simply erroneous 'from_date' data.
-- `titles` table:
WITH min_from_date AS (
    SELECT emp_no, MIN(from_date) AS earliest_from_date
    FROM titles
    GROUP BY emp_no
)
SELECT 
  d.emp_no, 
  d.hire_date, 
  m.earliest_from_date,
  CASE 
    WHEN d.hire_date < m.earliest_from_date THEN 'Earlier'
    WHEN d.hire_date > m.earliest_from_date THEN 'Later'
    ELSE 'Same'
  END AS hire_date_position
FROM emp_details AS d
JOIN min_from_date AS m ON d.emp_no = m.emp_no
WHERE d.hire_date <> m.earliest_from_date;

-- `dept_emp` table:
WITH min_from_date AS (
    SELECT emp_no, MIN(from_date) AS earliest_from_date
    FROM dept_emp
    GROUP BY emp_no
)
SELECT 
  d.emp_no, 
  d.hire_date, 
  m.earliest_from_date,
  CASE 
    WHEN d.hire_date < m.earliest_from_date THEN 'Earlier'
    WHEN d.hire_date > m.earliest_from_date THEN 'Later'
    ELSE 'Same'
  END AS hire_date_position
FROM emp_details AS d
JOIN min_from_date AS m ON d.emp_no = m.emp_no
WHERE d.hire_date <> m.earliest_from_date;

-- `salaries` table:
WITH min_from_date AS (
    SELECT emp_no, MIN(from_date) AS earliest_from_date
    FROM salaries
    GROUP BY emp_no
)
SELECT 
  d.emp_no, 
  d.hire_date, 
  m.earliest_from_date,
  CASE 
    WHEN d.hire_date < m.earliest_from_date THEN 'Earlier'
    WHEN d.hire_date > m.earliest_from_date THEN 'Later'
    ELSE 'Same'
  END AS hire_date_position
FROM emp_details AS d
JOIN min_from_date AS m ON d.emp_no = m.emp_no
WHERE d.hire_date <> m.earliest_from_date;

-----------------------------------------------

-- The following three queries update the salaries, dept_emp, and titles tables respectively.
-- Each query modifies the original table by replacing the earliest 'from_date' for each employee (emp_no) with their 'hire_date' from the emp_details table, if they are not the same.
-- This replacement is done under the assumption that each employee should have been assigned salary, dept_no and title records from the time of hire, and that the earliest records
-- of these fields recorded in the original tables are the ones assigned to them at the time of hire.
-- Update `salaries` table:
UPDATE salaries s
INNER JOIN emp_details d ON s.emp_no = d.emp_no
INNER JOIN (SELECT emp_no, MIN(from_date) AS earliest_from_date FROM salaries GROUP BY emp_no) sal 
ON s.emp_no = sal.emp_no
SET s.from_date = CASE WHEN s.from_date = sal.earliest_from_date THEN d.hire_date ELSE s.from_date END;

-- Update `dept_emp` table:
UPDATE dept_emp de
INNER JOIN emp_details d ON de.emp_no = d.emp_no
INNER JOIN (SELECT emp_no, MIN(from_date) AS earliest_from_date FROM dept_emp GROUP BY emp_no) demp 
ON de.emp_no = demp.emp_no
SET de.from_date = CASE WHEN de.from_date = demp.earliest_from_date THEN d.hire_date ELSE de.from_date END;

-- Update `titles` table:
UPDATE titles t
INNER JOIN emp_details d ON t.emp_no = d.emp_no
INNER JOIN (SELECT emp_no, MIN(from_date) AS earliest_from_date FROM titles GROUP BY emp_no) tit 
ON t.emp_no = tit.emp_no
SET t.from_date = CASE WHEN t.from_date = tit.earliest_from_date THEN d.hire_date ELSE t.from_date END;

-----------------------------------------------

-- The following three queries identifies potential discontinuities in each employee's record by finding rows where the to_date does not lead into the from_date of the subsequent row for the same emp_no.
-- The results show that this only occurs for the `dept_emp` table. This is due to the fact that some employees can belong to different departments concurrently.
-- This can be ignored as it is not an issue of data integrity, is not relevant to our scope of analysis and is a minor occurence (26 rows).
-- `salaries` table:
SELECT t1.*
FROM (
    SELECT 
        emp_no, 
        salary, 
        from_date, 
        to_date, 
        LEAD(from_date) OVER (PARTITION BY emp_no ORDER BY from_date) as next_from_date
    FROM salaries
) t1
WHERE t1.to_date != t1.next_from_date;

-- `dept_emp` table:
SELECT t1.*
FROM (
    SELECT 
        emp_no, 
        dept_no, 
        from_date, 
        to_date, 
        LEAD(from_date) OVER (PARTITION BY emp_no ORDER BY from_date) as next_from_date
    FROM dept_emp
) t1
WHERE t1.to_date != t1.next_from_date;

-- `titles` table:
SELECT t1.*
FROM (
    SELECT 
        emp_no, 
        title, 
        from_date, 
        to_date, 
        LEAD(from_date) OVER (PARTITION BY emp_no ORDER BY from_date) as next_from_date
    FROM titles
) t1
WHERE t1.to_date != t1.next_from_date;

-----------------------------------------------

-- Check for duplicate salary records
SELECT emp_no, from_date, COUNT(*)
FROM salaries
GROUP BY emp_no, from_date
HAVING COUNT(*) > 1;

-----------------------------------------------

-- Check for any from_date == to_date
SELECT * FROM salaries
WHERE to_date = from_date;

-- In the salaries table of the database, the from_date and to_date fields typically represent the period during which a specific salary was applicable to an employee.
-- Usually, from_date is the start date when the employee began receiving that salary, and to_date is the end date when that salary stopped being applicable.
-- However, in some instances, from_date and to_date are identical. These cases suggest that the salary rate was applicable for only a single day, which is unlikely in a realistic employment scenario.
-- It's more plausible that these instances represent records where the employee's salary rate changed, and the to_date was set as the same day as the from_date as a default or placeholder.
-- These records could lead to potential misinterpretation or miscalculation in analysis (for example, when calculating headcount in DAX, they might be excluded because they fall out of range),
-- Adding 1 day to the to_date will turn these instances into a two-day period, making them more realistically interpretable and ensuring they're included appropriately in any date-based calculations or analyses.
-- However, before making this adjustment, it's important to verify that this condition (from_date = to_date) only occurs in the latest salary record of each employee,
-- to avoid inaccurately extending the duration of non-final salary records.

-- The following query counts the number instances where the salary records of an employee has a from_date == to_date (total_count1).
-- It also determines if all such instances occur only when the from_date is the latest date for each employee (emp_no) (total_count2).
WITH total_records AS (
  -- Count total number of records in table where from_date = to_date
  SELECT COUNT(*) AS count1
  FROM salaries
  WHERE to_date = from_date
),
latest_records AS (
  -- Count total number of records in table where from_date = to_date AND from_date is the latest of the emp_no
  SELECT COUNT(*) AS count2
  FROM salaries s1
  WHERE from_date = to_date
  AND from_date = (
    SELECT MAX(from_date)
    FROM salaries s2
    WHERE s1.emp_no = s2.emp_no
  )
)
SELECT 
  total_records.count1 AS total_count1,
  latest_records.count2 AS total_count2,
  CASE
    WHEN total_records.count1 = latest_records.count2 THEN 'Counts match'
    ELSE 'Counts do not match'
  END AS count_comparison
FROM total_records, latest_records;

-- The results of the above query show that cases where from_date == to_date only occurs in the latest salary record of each employee, so the to_date of such rows can be safely updated.
-- A condition to check for maximum from_date is still included in the following UPDATE query.
UPDATE salaries
JOIN (
    SELECT emp_no, MAX(from_date) AS max_from_date
    FROM salaries
    GROUP BY emp_no
) AS s2 ON salaries.emp_no = s2.emp_no AND salaries.from_date = s2.max_from_date
SET to_date = DATE_ADD(to_date, INTERVAL 1 DAY)
WHERE from_date = to_date;

-----------------------------------------------

-- Create a view that associates each salary record with the corresponding department number (dept_no) and job title (title) that the employee held
-- during the period of that salary, based on the from_date and to_date. In case of overlaps, the most recent dept_no / job title record is chosen.
-- Changes to an employee's departments or titles during the period of a salary will not be reflected in the view as the view does not split salary periods.
-- Cases where an employee belongs to multiple departments concurrently will not be taken into account, and the most recent department will be chosen.
CREATE VIEW emp_salaries AS
SELECT 
  s.emp_no, 
  s.salary, 
  s.from_date, 
  s.to_date,
  (SELECT d.dept_no 
   FROM dept_emp d 
   WHERE s.emp_no = d.emp_no AND d.from_date <= s.from_date AND d.to_date >= s.from_date
   ORDER BY d.to_date DESC LIMIT 1) AS dept_no,
  (SELECT t.title 
   FROM titles t 
   WHERE s.emp_no = t.emp_no AND t.from_date <= s.from_date AND t.to_date >= s.from_date
   ORDER BY t.to_date DESC LIMIT 1) AS title
FROM salaries s;
