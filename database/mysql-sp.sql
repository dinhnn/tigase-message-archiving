--
--  Tigase Message Archiving Component
--  Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published by
--  the Free Software Foundation, either version 3 of the License.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--
--  You should have received a copy of the GNU Affero General Public License
--  along with this program. Look for COPYING file in the top folder.
--  If not, see http://www.gnu.org/licenses/.

-- QUERY START:
drop procedure if exists Tig_MA_GetHasTagsQuery;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetBodyContainsQuery;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetMessages;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetMessagesCount;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetCollections;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetCollectionsCount;
-- QUERY END:

-- QUERY START:
drop function if exists Tig_MA_EnsureJid;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_AddMessage;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_AddTagToMessage;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_RemoveMessages;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_DeleteExpiredMessages;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetTagsForUser;
-- QUERY END:

-- QUERY START:
drop procedure if exists Tig_MA_GetTagsForUserCount;
-- QUERY END:

-- QUERY START:
drop function if exists Tig_MA_GetHasTagsQuery;
-- QUERY END:

-- QUERY START:
drop function if exists Tig_MA_GetBodyContainsQuery;
-- QUERY END:

-- QUERY START:
delimiter //
-- QUERY END:

-- QUERY START:
create function Tig_MA_GetHasTagsQuery(_in_str text CHARSET utf8) returns text CHARSET utf8
begin
	if _in_str is not null then
		return CONCAT(' and exists(select 1 from tig_ma_msgs_tags mt inner join tig_ma_tags t on mt.tag_id = t.tag_id where m.msg_id = mt.msg_id and t.owner_id = o.jid_id and t.tag IN (', _in_str, '))');
	else
		return '';
	end if;
end //
-- QUERY END:

-- QUERY START:
create function Tig_MA_GetBodyContainsQuery(_in_str text CHARSET utf8) returns text CHARSET utf8
begin
	if _in_str is not null then
		return CONCAT(' and m.body like ', replace(_in_str, N''',''', N''' and m.body like = '''));
	else
		return '';
	end if;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetMessages( _ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8, _from timestamp, _to timestamp, _tags text CHARSET utf8, _contains text CHARSET utf8, _limit int, _offset int)
begin
	if _tags is not null or _contains is not null then
		set @ownerJid = _ownerJid;
		set @buddyJid = _buddyJid;
		set @from = _from;
		set @to = _to;
		set @limit = _limit;
		set @offset = _offset;
		select Tig_MA_GetHasTagsQuery(_tags) into @tags_query;
		select Tig_MA_GetBodyContainsQuery(_contains) into @contains_query;
		set @msgs_query = 'select m.msg, m.ts, m.direction, b.jid
		from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(?) and o.jid = ?
			and (? is null or (b.jid_sha1 = SHA1(?) and b.jid = ?))
			and (? is null or m.ts >= ?)
			and (? is null or m.ts <= ?)';
		set @pagination_query = ' limit ? offset ?';
		set @query = CONCAT(@msgs_query, @tags_query, @contains_query, ' order by m.ts', @pagination_query);
		prepare stmt from @query;
		execute stmt using @ownerJid, @ownerJid, @buddyJid, @buddyJid, @buddyJid, @from, @from, @to, @to, @limit, @offset;
		deallocate prepare stmt;
	else
		select m.msg, m.ts, m.direction, b.jid
		from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
			and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
			and (_from is null or m.ts >= _from)
			and (_to is null or m.ts <= _to)
		order by m.ts
		limit _limit offset _offset;
	end if;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetMessagesCount( _ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8, _from timestamp, _to timestamp, _tags text CHARSET utf8, _contains text CHARSET utf8)
begin
	if _tags is not null or _contains is not null then
		set @ownerJid = _ownerJid;
		set @buddyJid = _buddyJid;
		set @from = _from;
		set @to = _to;
		select Tig_MA_GetHasTagsQuery(_tags) into @tags_query;
		select Tig_MA_GetBodyContainsQuery(_contains) into @contains_query;
		set @msgs_query = 'select count(m.msg_id)
		from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(?) and o.jid = ?
			and (? is null or (b.jid_sha1 = SHA1(?) and b.jid = ?))
			and (? is null or m.ts >= ?)
			and (? is null or m.ts <= ?)';
		set @query = CONCAT(@msgs_query, @tags_query, @contains_query);
		prepare stmt from @query;
		execute stmt using @ownerJid, @ownerJid, @buddyJid, @buddyJid, @buddyJid, @from, @from, @to, @to;
		deallocate prepare stmt;
	else
		select count(m.msg_id)
		from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
			and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
			and (_from is null or m.ts >= _from)
			and (_to is null or m.ts <= _to);
	end if;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetCollections( _ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8, _from timestamp, _to timestamp, _tags text CHARSET utf8, _contains text CHARSET utf8, _byType smallint, _limit int, _offset int)
begin
	if _tags is not null or _contains is not null then
		set @ownerJid = _ownerJid;
		set @buddyJid = _buddyJid;
		set @from = _from;
		set @to = _to;
		set @limit = _limit;
		set @offset = _offset;
		select Tig_MA_GetHasTagsQuery(_tags) into @tags_query;
		select Tig_MA_GetBodyContainsQuery(_contains) into @contains_query;
		set @msgs_query = 'select min(m.ts), b.jid';
		if _byType = 1 then
			set @msgs_query = CONCAT( @msgs_query, ', case when m.type = ''groupchat'' then ''groupchat'' else '''' end as `type`');
		else
			set @msgs_query = CONCAT( @msgs_query, ', null as `type`');
		end if;
		set @msgs_query = CONCAT( @msgs_query,' from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(?) and o.jid = ?
			and (? is null or (b.jid_sha1 = SHA1(?) and b.jid = ?))
			and (? is null or m.ts >= ?)
			and (? is null or m.ts <= ?)');
		set @groupby_query = '';
		if _byType = 1 then
			select ' group by date(m.ts), m.buddy_id, b.jid, case when m.type = ''groupchat'' then ''groupchat'' else '''' end' into @groupby_query;
		else
			select ' group by date(m.ts), m.buddy_id, b.jid' into @groupby_query;
		end if;
		set @pagination_query = ' limit ? offset ?';
		set @query = CONCAT(@msgs_query, @tags_query, @contains_query, @groupby_query, ' order by m.ts, b.jid', @pagination_query);
		prepare stmt from @query;
		execute stmt using @ownerJid, @ownerJid, @buddyJid, @buddyJid, @buddyJid, @from, @from, @to, @to, @limit, @offset;
		deallocate prepare stmt;
	else
		if _byType = 1 then
			select min(m.ts), b.jid, case when m.type = 'groupchat' then 'groupchat' else '' end as `type`
			from tig_ma_msgs m 
				inner join tig_ma_jids o on m.owner_id = o.jid_id 
				inner join tig_ma_jids b on b.jid_id = m.buddy_id
			where 
				o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
				and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
				and (_from is null or m.ts >= _from)
				and (_to is null or m.ts <= _to)
			group by date(m.ts), m.buddy_id, b.jid, case when m.type = 'groupchat' then 'groupchat' else '' end 
			order by m.ts, b.jid
			limit _limit offset _offset;
		else
			select min(m.ts), b.jid, null as `type`
			from tig_ma_msgs m 
				inner join tig_ma_jids o on m.owner_id = o.jid_id 
				inner join tig_ma_jids b on b.jid_id = m.buddy_id
			where 
				o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
				and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
				and (_from is null or m.ts >= _from)
				and (_to is null or m.ts <= _to)
			group by date(m.ts), m.buddy_id, b.jid
			order by m.ts, b.jid
			limit _limit offset _offset;
		end if;
	end if;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetCollectionsCount( _ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8, _from timestamp, _to timestamp, _tags text CHARSET utf8, _contains text CHARSET utf8, _byType smallint)
begin
	if _tags is not null or _contains is not null then
		set @ownerJid = _ownerJid;
		set @buddyJid = _buddyJid;
		set @from = _from;
		set @to = _to;
		select Tig_MA_GetHasTagsQuery(_tags) into @tags_query;
		select Tig_MA_GetBodyContainsQuery(_contains) into @contains_query;
		set @msgs_query = 'select count(1) from (select min(m.ts), b.jid';
		if _byType = 1 then
			set @msgs_query = CONCAT( @msgs_query, ', case when m.type = ''groupchat'' then ''groupchat'' else '''' end as `type`');
		end if;
		set @msgs_query = CONCAT( @msgs_query,' from tig_ma_msgs m 
			inner join tig_ma_jids o on m.owner_id = o.jid_id 
			inner join tig_ma_jids b on b.jid_id = m.buddy_id
		where 
			o.jid_sha1 = SHA1(?) and o.jid = ?
			and (? is null or (b.jid_sha1 = SHA1(?) and b.jid = ?))
			and (? is null or m.ts >= ?)
			and (? is null or m.ts <= ?)');
		if _byType = 1 then
			set @groupby_query = ' group by date(m.ts), m.buddy_id, b.jid, case when m.type = ''groupchat'' then ''groupchat'' else '''' end';
		else
			set @groupby_query = ' group by date(m.ts), m.buddy_id, b.jid';
		end if;
		set @query = CONCAT(@msgs_query, @tags_query, @contains_query, @groupby_query, ' ) x');
		prepare stmt from @query;
		execute stmt using @ownerJid, @ownerJid, @buddyJid, @buddyJid, @buddyJid, @from, @from, @to, @to;
		deallocate prepare stmt;
	else
		if _byType = 1 then
			select count(1) from (
				select min(m.ts), b.jid, case when m.type = 'groupchat' then 'groupchat' else '' end as `type`
				from tig_ma_msgs m 
					inner join tig_ma_jids o on m.owner_id = o.jid_id 
					inner join tig_ma_jids b on b.jid_id = m.buddy_id
				where 
					o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
					and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
					and (_from is null or m.ts >= _from)
					and (_to is null or m.ts <= _to)
				group by date(m.ts), m.buddy_id, b.jid, case when m.type = 'groupchat' then 'groupchat' else '' end 
			) x;
		else
			select count(1) from (
				select min(m.ts), b.jid
				from tig_ma_msgs m 
					inner join tig_ma_jids o on m.owner_id = o.jid_id 
					inner join tig_ma_jids b on b.jid_id = m.buddy_id
				where 
					o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
					and (_buddyJid is null or (b.jid_sha1 = SHA1(_buddyJid) and b.jid = _buddyJid))
					and (_from is null or m.ts >= _from)
					and (_to is null or m.ts <= _to)
				group by date(m.ts), m.buddy_id, b.jid
			) x;
		end if;
	end if;
end //
-- QUERY END:

-- QUERY START:
create function Tig_MA_EnsureJid(_jid varchar(2049) CHARSET utf8) returns bigint DETERMINISTIC
begin
	declare _jid_id bigint;
	declare _jid_sha1 char(40);

	select SHA1(_jid) into _jid_sha1;
	select jid_id into _jid_id from tig_ma_jids where jid_sha1 = _jid_sha1;
	if _jid_id is null then
		insert into tig_ma_jids (jid, jid_sha1, `domain`)
			values (_jid, _jid_sha1, SUBSTR(jid, LOCATE('@', _jid) + 1))
			on duplicate key update jid_id = LAST_INSERT_ID(jid_id);
		select LAST_INSERT_ID() into _jid_id;
	end if;

	return (_jid_id);
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_AddMessage(_ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8,
	 _buddyRes varchar(1024)  CHARSET utf8, _ts timestamp, _direction smallint, _type varchar(20) CHARSET utf8,
	 _body text CHARSET utf8, _msg text CHARSET utf8, _hash varchar(50) CHARSET utf8)
begin
	declare _owner_id bigint;
	declare _buddy_id bigint;
	declare _msg_id bigint;

	START TRANSACTION;
	select Tig_MA_EnsureJid(_ownerJid) into _owner_id;
	select Tig_MA_EnsureJid(_buddyJid) into _buddy_id;

	insert into tig_ma_msgs (owner_id, buddy_id, buddy_res, ts, direction, `type`, body, msg, stanza_hash)
		values (_owner_id, _buddy_id, _buddyRes, _ts, _direction, _type, _body, _msg, _hash)
		on duplicate key update direction = direction;

	select LAST_INSERT_ID() into _msg_id;
	COMMIT;

	select _msg_id as msg_id;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_AddTagToMessage(_msgId bigint, _tag varchar(255) CHARSET utf8)
begin
	declare _owner_id bigint;
	declare _tag_id bigint;

	START TRANSACTION;
	select owner_id into _owner_id from tig_ma_msgs where msg_id = _msgId;
	select tag_id into _tag_id from tig_ma_tags where owner_id = _owner_id and tag = _tag;
	if _tag_id is null then
		insert into tig_ma_tags (owner_id, tag) 
			values (_owner_id, _tag)
			on duplicate key update tag_id = LAST_INSERT_ID(tag_id);
		select LAST_INSERT_ID() into _tag_id;
	end if;
	insert into tig_ma_msgs_tags (msg_id, tag_id) values (_msgId, _tag_id) on duplicate key update tag_id = tag_id;
	COMMIT;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_RemoveMessages(_ownerJid varchar(2049) CHARSET utf8, _buddyJid varchar(2049) CHARSET utf8, _from timestamp, _to timestamp)
begin
	set @_owner_id = 0;
	set @_buddy_id = 0;
	select jid_id into @_owner_id from tig_ma_jids j where j.jid_sha1 = SHA1(_ownerJid) and jid = _ownerJid;
	select jid_id into @_buddy_id from tig_ma_jids j where j.jid_sha1 = SHA1(_buddyJid) and jid = _buddyJid;
	delete from tig_ma_msgs where owner_id = @_owner_id and buddy_id = @_buddy_id and ts >= _from and ts <= _to;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_DeleteExpiredMessages(_domain varchar(1024) CHARSET utf8, _before timestamp)
begin
	delete from tig_ma_msgs where ts < _before and exists (select 1 from tig_ma_jids j where j.jid_id = owner_id and `domain` = _domain);
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetTagsForUser(_ownerJid varchar(2049) CHARSET utf8, _tagStartsWith varchar(255) CHARSET utf8, _limit int, _offset int)
begin
	select tag 
		from tig_ma_tags t 
		inner join tig_ma_jids o on o.jid_id = t.owner_id 
		where o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid
			and t.tag like _tagStartsWith
		order by t.tag
		limit _limit offset _offset;
end //
-- QUERY END:

-- QUERY START:
create procedure Tig_MA_GetTagsForUserCount(_ownerJid varchar(2049) CHARSET utf8, _tagStartsWith varchar(255) CHARSET utf8)
begin
	select count(tag_id) from tig_ma_tags t inner join tig_ma_jids o on o.jid_id = t.owner_id where o.jid_sha1 = SHA1(_ownerJid) and o.jid = _ownerJid and t.tag like _tagStartsWith;
end //
-- QUERY END:

-- QUERY START:
delimiter ;
-- QUERY END: