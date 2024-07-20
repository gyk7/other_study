-- 1. 인덱스
--  (1) 인덱스 생성에 따른 성능 차이
SELECT
	last_name
FROM employees
WHERE employees.birth_date = '1953-09-02'
AND employees.first_name = 'Georgi';

--   ▶((birth_date, first_name) 인덱스 생성한 후)
CREATE index idx_date_name ON gayoung.employees(birth_date, first_name);
SHOW index FROM gayoung.employees;

--  결과 : 인덱스 생성 전, 후 비교했을 때 속도는 약 7배 차이, 쿼리 비용은 약 86000배 차이남.

--  (2) 인덱스 컬럼 순서에 따른 성능 차이
SELECT
	last_name
FROM employees
WHERE employees.birth_date != '1953-09-02'
AND employees.first_name = 'Georgi';

--   ▶(컬럼 순서가 반대인 (first_name, birth_date) 인덱스 생성한 후)
CREATE index idx_name_date ON gayoung.employees(first_name, birth_date);
SHOW index FROM gayoung.employees;

   /*결과 :(birth_date, first_name) 인덱스 생성했을 때와 (first_name, birth_date) 인덱스 생성했을 때의 속도 차이는 약 15배, 
   쿼리 비용은 약 265배 차이남.*/


-- 2. 파티셔닝 최적화
-- ▶ 파티셔닝 생성
-- (출생년도 별로 3개의 파티션으로 구분)
/* part1 : 1953년 미만
   part2 : 1953년~1960년 미만
   part3 : 1960년 이상
*/

CREATE TABLE employees {
	emp_no 		INT 		  NOT NULL,
	birth_date 	DATE 		  NOT NULL,
	first_name 	VARCHAR(14)   NOT NULL,
	last_name 	VARCHAR(16)   NOT NULL,
	gender 		ENUM('M','F') NOT NULL,
	hire_date 	DATE 		  NOT NULL
)
PARTITION BY RANGE(year(birth_date)) (
	PARTITION part1 VALUES LESS THAN (1953),
	PARTITION part2 VALUES LESS THAN (1960),
	PARTITION part3 VALUES LESS THAN MAXVALUE
);

-- ▶파티션 정보 확인
SELECT
	TABLE_SCHEMA, TABLE_NAME, PARTITION_NAME, PARTITION_ORDINAL_POSITION, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_NAME='employees';

-- ▶파티셔닝 속도, 성능 차이
--  ex) 1953년 이전 출생한 직원 수 검색
-- (1)
SELECT
	count(emp_no)
FROM employees
WHERE year(birth_date) < 1953;
-- ※파티션 없을 때, 파티션이 존재하지만 제대로 적용하지 않을 때 
-- 속도는 비슷하고, 쿼리비용은 오히려 파티션이 존재할 때 더 큼.
-- 즉, 파티션을 만들더라도 쿼리를 제대로 작성하지 않으면 속도, 쿼리 비용에 도움되지 않음.

-- (2)
SELECT
	count(emp_no)
FROM employees
WHERE birth_date < DATE_FORMAT('1953-01-01', '%Y%m%d');
-- 결과 :파티션을 제대로 생성하면, 속도가 약 8배 차이, 쿼리 비용은 약 14배 차이남.

-- (3) 결론
-- 1, 2번에서 모두 1953년 이전에 출생한 직원 수를 검색하지만 
-- 1번에서는 'birth_date'의 연도를 추출하여 비교하기 때문에 파티션 적용이 제대로 되지 않았고,
-- 2번에서는 'birth_date' 자체를 직접 비교하는 조건에서는 파티션 적용이 제대로 되었음.
