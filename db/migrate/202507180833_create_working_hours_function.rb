class CreateWorkingHoursFunction < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE FUNCTION working_hours_between(
        start_time DATETIME,
        end_time DATETIME,
        work_start TIME,
        work_end TIME,
        workdays VARCHAR(20)
      ) RETURNS DOUBLE
      DETERMINISTIC
      BEGIN
        DECLARE total_hours DOUBLE DEFAULT 0;
        WHILE start_time < end_time DO
          IF FIND_IN_SET(DAYOFWEEK(start_time) - 1, workdays) > 0 THEN
            IF TIME(start_time) >= work_start AND TIME(start_time) < work_end THEN
              SET total_hours = total_hours + 1;
            END IF;
          END IF;
          SET start_time = DATE_ADD(start_time, INTERVAL 1 HOUR);
        END WHILE;
        RETURN total_hours;
      END;
    SQL
  end

  def down
    execute 'DROP FUNCTION IF EXISTS working_hours_between'
  end
end
