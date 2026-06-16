-- DBeaver: execute this file as a script (Alt+X).
-- Drops all application objects from the current schema.

BEGIN
    FOR obj IN (
        SELECT object_type, object_name
        FROM user_objects
        WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'TABLE', 'SEQUENCE')
        ORDER BY
            CASE object_type
                WHEN 'PACKAGE BODY' THEN 1
                WHEN 'PACKAGE' THEN 2
                WHEN 'TRIGGER' THEN 3
                WHEN 'TABLE' THEN 4
                WHEN 'SEQUENCE' THEN 5
                ELSE 6
            END
    ) LOOP
        BEGIN
            IF obj.object_type = 'TABLE' THEN
                EXECUTE IMMEDIATE 'DROP TABLE "' || obj.object_name || '" CASCADE CONSTRAINTS PURGE';
            ELSIF obj.object_type = 'PACKAGE BODY' THEN
                NULL;
            ELSE
                EXECUTE IMMEDIATE 'DROP ' || obj.object_type || ' "' || obj.object_name || '"';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;
END;
/
