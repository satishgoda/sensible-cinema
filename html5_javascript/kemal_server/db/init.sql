--run with recreate.sh script...

CREATE TABLE URLS (
   id INTEGER PRIMARY KEY,
   url           TEXT    NOT NULL,
   name          TEXT    NOT NULL
);

  
CREATE TABLE EDITS (
   id             INTEGER PRIMARY KEY,
   start          REAL NOT NULL,
   endy           REAL NOT NULL,
   category       TEXT NOT NULL, 
   subcategory    TEXT NOT NULL, 
   details        TEXT NOT NULL, 
   default_action TEXT NOT NULL, 
   url_id         INT, FOREIGN KEY(URL_ID) REFERENCES URLS(ID)
);

insert into urls (url, name) values ("http://url", 'a_name";alert("xss");"'); -- no ID needed
insert into edits (start, endy, category, subcategory, details, default_action, url_id) values
    (20090.50, 20100.50, "a category", "a subcat", "details", "mute", last_insert_rowid());

insert into urls (url, name) values ("https://www.netflix.com/watch/80016224", 'meet the mormons [test]');
insert into edits (start, endy, category, subcategory, details, default_action, url_id) values
      (2.0, 7.0, "a category", "a subcat", "details", "skip", (select id from urls where url='https://www.netflix.com/watch/80016224'));
insert into edits (start, endy, category, subcategory, details, default_action, url_id) values
          (10.0, 30.0, "a category", "a subcat", 3, "details", "mute", (select id from urls where url='https://www.netflix.com/watch/80016224'));

alter table urls add amazon_episode_number INTEGER NOT NULL DEFAULT 0;
alter table urls add amazon_episode_name TEXT NOT NULL DEFAULT "";

-- guess I didn't have any unique url constraint before this, only id...
-- also gets us an index by both :)
CREATE UNIQUE INDEX url_episode_num ON urls(url, amazon_episode_number);

-- output some to screen
select * from urls;
select * from edits;
