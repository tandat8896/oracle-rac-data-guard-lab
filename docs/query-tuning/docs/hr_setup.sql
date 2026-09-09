CREATE TABLE departments (
  dept_id    NUMBER PRIMARY KEY,
  dept_name  VARCHAR2(50),
  location   VARCHAR2(50)
);

CREATE TABLE employees (
  emp_id     NUMBER PRIMARY KEY,
  name       VARCHAR2(50),
  dept_id    NUMBER REFERENCES departments(dept_id),
  salary     NUMBER,
  hiredate   DATE
);

BEGIN
  FOR d IN 1..10 LOOP
    INSERT INTO departments VALUES (d, 'Dept_' || d, 'Location_' || MOD(d, 5));
  END LOOP;

  FOR e IN 1..100000 LOOP
    INSERT INTO employees VALUES (
      e, 'Emp_' || e, MOD(e, 10) + 1,
      ROUND(DBMS_RANDOM.VALUE(3000, 8000), 2),
      SYSDATE - DBMS_RANDOM.VALUE(1, 2000)
    );
  END LOOP;
  COMMIT;
END;
/
