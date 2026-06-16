-- DBeaver: execute this file as a script (Alt+X) on an existing database.
-- It upgrades a database created before question images were added.

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE question ADD image_path VARCHAR2(255 CHAR)';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1430 THEN
            RAISE;
        END IF;
END;


BEGIN
    DBMS_OUTPUT.PUT_LINE('Existing database upgraded.');
    DBMS_OUTPUT.PUT_LINE('Next step: execute sql/05_package_body.sql as a script to recompile quiz_platform.');
END;

