SELECT
    fk.table_name AS foreign_table,
    fk.column_name AS foreign_column,
    pk.table_name AS primary_table,
    pk.column_name AS primary_column
FROM
    information_schema.key_column_usage AS fk
JOIN
    information_schema.referential_constraints AS rc
    ON fk.constraint_name = rc.constraint_name
JOIN
    information_schema.key_column_usage AS pk
    ON rc.unique_constraint_name = pk.constraint_name
WHERE
    fk.table_name = 'your_table_name';