USE lesson_4;
/*
1.Создайте таблицу users_old, аналогичную таблице users.
 Создайте процедуру,  с помощью которой можно переместить любого (одного) 
 пользователя из таблицы users в таблицу users_old. 
(использование транзакции с выбором commit или rollback – обязательно).
*/
DROP TABLE IF EXISTS users_old;
CREATE TABLE users_old (
	id SERIAL PRIMARY KEY,
    firstname VARCHAR(50),
    lastname VARCHAR(50) COMMENT 'Фамилия',
    email VARCHAR(120) UNIQUE
);

DROP PROCEDURE IF EXISTS user_transfer;
DELIMITER //
CREATE PROCEDURE user_transfer(u_id int,
OUT  tran_result varchar(100))
BEGIN
	
	DECLARE `_rollback` BIT DEFAULT b'0';
	DECLARE code varchar(100);
	DECLARE error_string varchar(100); 

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
	BEGIN
 		SET `_rollback` = b'1';
 		GET stacked DIAGNOSTICS CONDITION 1
			code = RETURNED_SQLSTATE, error_string = MESSAGE_TEXT;
	END;

	START TRANSACTION;
	
	INSERT INTO users_old (id, firstname, lastname, email)
	SELECT id, firstname, lastname, email FROM users WHERE id = u_id;

	DELETE FROM users
	WHERE id=u_id;
	
	IF `_rollback` THEN
		SET tran_result = CONCAT('! Error: ', code, ' Error text: ', error_string);
		ROLLBACK;
	ELSE
		SET tran_result = 'Ok';
		COMMIT;
	END IF;
END//
DELIMITER ;


/*
2. Создайте хранимую функцию hello(), которая будет возвращать приветствие, в зависимости от текущего времени суток. 
С 6:00 до 12:00 функция должна возвращать фразу "Доброе утро", с 12:00 до 18:00 функция должна возвращать фразу "Добрый день", 
с 18:00 до 00:00 — "Добрый вечер", с 00:00 до 6:00 — "Доброй ночи".
*/

DROP FUNCTION IF EXISTS hello;
DELIMITER //
CREATE FUNCTION hello() 
	RETURNS VARCHAR(25)
	DETERMINISTIC
BEGIN
DECLARE result_text VARCHAR(25);
SET @time = HOUR(NOW());
SELECT CASE 
	WHEN (@time > 6 AND @time < 12) THEN 'Доброе утро'
	WHEN (@time > 12 AND @time < 18) THEN 'Добрый день'
	WHEN (@time > 18 AND @time < 24) THEN 'Доброй ночи'
	ELSE 'Добрый вечер'
END INTO result_text;
RETURN result_text;
END//

DELIMITER ;

SELECT hello() AS 'Greeting';

/* 3. Создайте таблицу logs типа Archive. Пусть при каждом создании записи в таблицах 
users, communities и messages в таблицу logs помещается время и дата создания записи, 
название таблицы, идентификатор первичного ключа.*/

/* !!! Archive - не поддерживает индексы, поэтому при определении
таблицы первичный ключ не указывается. !!! */

DROP TABLE IF EXISTS logs;
CREATE TABLE logs (
  table_name VARCHAR(20) NOT NULL,
  prkey_id INT UNSIGNED NOT NULL,
  time_rec /*created_at*/ DATETIME DEFAULT NOW()
) ENGINE = ARCHIVE;

DROP TRIGGER IF EXISTS users_log;
CREATE TRIGGER users_log AFTER INSERT ON users FOR EACH ROW
  INSERT INTO logs 
  	SET table_name = 'users',
      prkey_id = NEW.id;

DROP TRIGGER IF EXISTS communities_log;
CREATE TRIGGER communities_log AFTER INSERT ON communities FOR EACH ROW
  INSERT INTO logs 
    SET table_name = 'communities',
      pk_id = NEW.id;

DROP TRIGGER IF EXISTS messages_log;
CREATE TRIGGER messages_log AFTER INSERT ON messages FOR EACH ROW
  INSERT INTO logs 
    SET table_name = 'messages',
      pk_id = NEW.id;

  