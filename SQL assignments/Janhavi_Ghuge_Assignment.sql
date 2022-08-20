CREATE DATABASE webengage;
USE webengage;

-- 1) Creating table sessions and uninstalls

CREATE TABLE Sessions(
Name Varchar(20),
City Varchar(50),
Date datetime,
Action Varchar(20)
);

INSERT INTO Sessions VALUES ("Mahi",'Delhi','2021-05-06 0:00', 'Session_Started');
INSERT INTO Sessions VALUES ("Mahi",'Delhi','2021-05-07 7:00', 'Session_Started'),("Mahi",'Delhi','2021-05-07 8:00', 'Session_Started'),("Mahi",'Delhi','2021-05-08 9:00', 'Session_Started'),
							("Rajesh",'Banglore','2021-05-06 9:00', 'Session_Started'),("Rajesh",'Banglore','2021-05-07 8:00', 'Session_Started'),("Rajesh",'Banglore','2021-05-07 8:30', 'Session_Started'),("Rajesh",'Banglore','2021-05-08 6:00', 'Session_Started'),
							("Sam",'Pune','2021-05-06 5:00', 'Session_Started'),("Sam",'Pune','2021-05-08 6:00', 'Session_Started'),("Sam",'Pune','2021-05-07 0:00', 'Session_Started'),("Sam",'Pune','2021-05-08 0:00', 'Session_Started'),("Sam",'Pune','2021-05-09 0:00', 'Session_Started'),
                            ("Vishal",'Mumbai','2021-05-06 0:00', 'Session_Started'),("Vishal",'Mumbai','2021-05-07 0:00', 'Session_Started'),("Vishal",'Mumbai','2021-05-08 0:00', 'Session_Started');
                            
				
CREATE TABLE uninstalls(
Name Varchar(20),
City Varchar(50),
Date datetime,
Action Varchar(20)
);

INSERT INTO uninstalls VALUES ("Mahi",'Delhi','2021-05-07 7:00', 'Uninstalls'),
							  ("Sam",'Pune','2021-05-09 9:00', 'Uninstalls'),
                              ("Chirag",'Kolkata','2021-05-10 9:00', 'Uninstalls');



-- 2) Query to fetch users with:

-- a) most sessions (most active user)
SELECT Name
FROM sessions
GROUP BY name 
ORDER BY COUNT(*) DESC
LIMIT 1;

-- b) below average sessions
SELECT name
FROM 
	(SELECT Name, num_sessions, 
			AVG(num_sessions) OVER() AS avg_sessions
	FROM
		(SELECT 
				Name,
				COUNT(*) AS num_sessions
		FROM sessions
		GROUP BY name
        ) AS T1
	) AS T2
WHERE num_sessions < avg_sessions;


-- 3)Query to fetch the most active user on each day from May 6th,21 to May 10th,21
SELECT Date, Name, session_count
FROM
	(SELECT Date, Name,session_count,
			RANK() OVER(PARTITION BY Date ORDER BY session_count DESC) ranks
	FROM
		(SELECT 
			date(Date) AS date,Name,COUNT(name) AS session_count
		FROM sessions
		WHERE date BETWEEN '2021-05-06' AND '2021-05-10'
		GROUP BY date(Date),Name
		ORDER BY date(Date)
        ) AS t1
	) AS t2
WHERE ranks = 1;


-- 4)a)
SELECT 		
		sessions.name, 
        COUNT(sessions.name) AS sessions_count,
        CASE WHEN uninstalls.Action = 'Uninstalls' THEN 'Yes' ELSE 'No' END AS App_uninstalled_flag
FROM sessions
LEFT JOIN uninstalls
ON 
	sessions.name = uninstalls.name
GROUP BY sessions.name;

-- 4)b)
SELECT 		
		sessions.name, 
        COUNT(sessions.name) AS sessions_count,
        CASE WHEN uninstalls.Action = 'Uninstalls' THEN 'Yes' ELSE 'No' END AS App_uninstalled_flag
FROM sessions
LEFT JOIN uninstalls
ON 
	sessions.name = uninstalls.name
GROUP BY sessions.name
UNION
SELECT 		
		uninstalls.name, 
        COUNT(sessions.name) AS sessions_count,
        CASE WHEN uninstalls.Action = 'Uninstalls' THEN 'Yes' ELSE 'No' END AS App_uninstalled_flag
FROM sessions
RIGHT JOIN uninstalls
ON 
	sessions.name = uninstalls.name
GROUP BY sessions.name;



-- 5) Redesigning the sessions and uninstalls table
-- Divide sessions table into 2 table 1st customer table with user id as primary key 
-- and 2nd sessions table with session id as primary key and user id in it as foreign key to reduce redundancy in sessions table

CREATE TABLE customers(
user_id INT NOT NULL,
Name Varchar(20),
City Varchar(50),
PRIMARY KEY(user_id)
);

INSERT INTO customers VALUES (1,"Mahi",'Delhi'),(2,"Rajesh",'Banglore'),
							 (3,"Sam",'Pune'),(4,"Vishal",'Mumbai');


CREATE TABLE sessions_new(
session_id INT NOT NULL,
user_id INT NOT NULL,
Date datetime,
Action Varchar(20),
PRIMARY KEY(session_id),
FOREIGN KEY(user_id) REFERENCES customers(user_id)
);

INSERT INTO sessions_new VALUES (101,1,'2021-05-06 0:00', 'Session_Started'),
								(102,1,'2021-05-07 7:00', 'Session_Started'),
								(103,1,'2021-05-07 8:00', 'Session_Started'),
                                (104,1,'2021-05-08 9:00', 'Session_Started'),
                                (105,2,'2021-05-06 9:00', 'Session_Started'),
                                (106,2,'2021-05-07 8:00', 'Session_Started'),
                                (107,2,'2021-05-07 8:30', 'Session_Started'),
							    (108,2,'2021-05-08 6:00', 'Session_Started'),
                                (109,3,'2021-05-06 5:00', 'Session_Started'),
                                (110,3,'2021-05-08 6:00', 'Session_Started'),
                                (111,3,'2021-05-07 0:00', 'Session_Started'),
                                (112,3,'2021-05-08 0:00', 'Session_Started'),
                                (113,3,'2021-05-09 0:00', 'Session_Started'),
                                (114,4,'2021-05-06 0:00', 'Session_Started'),
                                (115,4,'2021-05-07 0:00', 'Session_Started'),
                                (116,4,'2021-05-08 0:00', 'Session_Started');
                                
INSERT INTO customers VALUES (5,"Chirag",'Kolkata');

INSERT INTO sessions_new VALUES (117,3,'2021-05-09 9:00', 'Session_Started'),
								(118,5,'2021-05-10 9:00', 'Session_Started');


CREATE TABLE uninstalls_new(
uninstall_session_id INT NOT NULL,
Action Varchar(20),
FOREIGN KEY(uninstall_session_id) REFERENCES sessions_new(session_id)
);

INSERT INTO uninstalls_new VALUES (102, 'Uninstalls'),
								  (117, 'Uninstalls'),
								  (118, 'Uninstalls');


-- to verify our structure the below query gives correct result
SELECT name,city,date,uninstalls_new.action
FROM uninstalls_new 
LEFT JOIN sessions_new
ON
	uninstalls_new.uninstall_session_id = sessions_new.session_id
JOIN customers
ON
	sessions_new.user_id = customers.user_id
		






