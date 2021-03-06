require 'rubygems' # This line not needed for ruby > 1.8
require 'twilio-ruby'
require 'sqlite3'

#account_sid = "AC0a2ca9664ccb810dece8e55031b4db98"
#application_sid=""
#auth_token = "2556e2e74acf97b82033febf170532fe"
#twiliophone="8163993325"

account_sid = "	AC1173bb9e0015a2e9d8071da3d23e8fd2"
application_sid="AP26ff4abb8bf80873042f426fca12ba12"
auth_token = "e91f1b52005b605ab1174ca15cb0584d"
twiliophone="8165459240"


@client = Twilio::REST::Client.new account_sid, auth_token
@db = SQLite3::Database.open "../db/development.sqlite3"

#process inbound messages
#@db.execute("update FONEFLARE set LASTSMSQUERY='2013-06-15 22:58:46 -0500'")
lastsmsquery=@db.get_first_value("select max(LASTSMSQUERY) from FONEFLARE limit 1")
rs=@client.account.sms.messages.list(:date_sent=>lastsmsquery)

rs.select! {|x| x.direction=="inbound"}
rs.reject! {|x| Time.parse(x.date_sent).to_s()==lastsmsquery}

if rs.count > 0
	lastsmsdate=Time.parse(rs[0].date_sent).to_s()
	@db.execute("update FONEFLARE set LASTSMSQUERY='"+lastsmsdate+"'")
		
	rs.sort! {|x,y| x.date_sent<=>y.date_sent}

	rs.each do |message|		
		def disableFlareAndResponderBuild(srcphone="")
			@db.execute "update FLARES set ACTIVE=0, updated_dt='"+Time.now.to_s()+"' where SRCPHONE='" + srcphone + "' and ACTIVE>=2"
			@db.execute "update RESPONDERS set ACTIVE=0, updated_dt='"+Time.now.to_s()+"' where SRCPHONE='" + srcphone + "' and ACTIVE>=2"
		end

		messagepending=true
		srcphone=message.from
		
		puts "ASSISTS TABLE"
		puts srcphone + " " + Time.parse(message.date_sent).to_s() + " " + message.body
		puts ""
		
		md=/^stopff$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			@db.execute "update FLARES set active=0, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"'"
			@db.execute "update RESPONDERS set active=0, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"'"
			@client.account.sms.messages.create(:body=>"Thank you for using FoneFlare.  All your flares and responders have been canceled.  You will not receive any new messages until you reactivate.", :to=>srcphone, :from=>twiliophone)			
			messagepending=false
		end
		
		md=/^flare new$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			@db.execute "insert into FLARES (srcphone, active, created_dt) values ('"+srcphone+"',2,'"+Time.now.to_s()+"')"
			fid=@db.get_first_value("select flare_id from FLARES where srcphone='"+srcphone+"' and active=2")
			@client.account.sms.messages.create(:body=>"You have created a new flare id F"+fid.to_s()+". Please record this flare id for future commands to FoneFlare.", :to=>srcphone, :from=>twiliophone)			
			@client.account.sms.messages.create(:body=>"What is the zip code of your flare?", :to=>srcphone, :from=>twiliophone)
			messagepending=false
		end
		
		md=/^flare cancel f[0-9]+$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			fid=/f[0-9]+$/i.match(message.body).to_s()[1..-1]
			ok=@db.get_first_value("select count(*) from FLARES where flare_id="+fid+" and srcphone='"+srcphone+"'")
			if ok>0
				@db.execute "update FLARES set active=0, updated_dt='"+Time.now.to_s()+"' where flare_id="+fid+" and srcphone='"+srcphone+"'"
				@client.account.sms.messages.create(:body=>"You have cancelled flare id F"+fid.to_s()+".", :to=>srcphone, :from=>twiliophone)			
			else
				@client.account.sms.messages.create(:body=>"Invalid flare id F"+fid.to_s()+".", :to=>srcphone, :from=>twiliophone)			
			end
			messagepending=false
		end
		
		md=/^flare call f[0-9]+$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			fid=/f[0-9]+$/i.match(message.body).to_s()[1..-1]
			ok=@db.get_first_value("select count(*) from FLARES where flare_id="+fid+" and srcphone='"+srcphone+"'")
			if ok>0
				#make conference call
			else
				@client.account.sms.messages.create(:body=>"Invalid flare id F"+fid.to_s()+".", :to=>srcphone, :from=>twiliophone)			
			end
			messagepending=false
		end

		md=/^resp avail$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			@db.execute "insert into RESPONDERS (srcphone, active, created_dt) values ('"+srcphone+"',2,'"+Time.now.to_s()+"')"
			rid=@db.get_first_value("select responder_id from RESPONDERS where srcphone='"+srcphone+"' and active=2")
			@client.account.sms.messages.create(:body=>"You have created a new responder id R"+rid.to_s()+". Please record this responder id for future commands to FoneFlare.", :to=>srcphone, :from=>twiliophone)			
			@client.account.sms.messages.create(:body=>"What is the zip code you can respond to?", :to=>srcphone, :from=>twiliophone)
			messagepending=false
		end

		md=/^resp quit$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			db.execute "update RESPONDERS set active=0, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"'"
			messagepending=false
		end
		
		md=/^resp f[0-9]+$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			fid=/f[0-9]+$/i.match(message.body).to_s()[1..-1]
			puts fid
			sql="
				select 	count(*) 
				from 	FLARES 	 as a
				where 	flare_id="+fid.to_s()+" 
						and exists	(
									select	*
									from 	RESPONDERS	as b
									where	srcphone='"+srcphone+"'
											and b.category=a.category
									)"
			ok=@db.get_first_value(sql)
			if ok>0
				sql="select	responder_id 
					from 	RESPONDERS	as a
							inner join FLARES as b
								on b.category=a.category
					where	a.srcphone='"+srcphone+"'
							and b.active=1"
				rid=@db.get_first_value(sql)
				sql="insert into ASSISTS 
						(flare_id, responder_id, created_dt) 
					values 
						(
						"+fid.to_s()+",
						"+rid.to_s()+",
						'"+Time.now.to_s()+"'
						)"
				@db.execute sql
				@db.execute "update RESPONDERS set active=0, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"'"
				@client.account.sms.messages.create(:body=>"You have responded to flare id F"+fid.to_s()+". You will not be active for any more flares until you notify FoneFlare that you are available.", :to=>srcphone, :from=>twiliophone)			
			else
				@client.account.sms.messages.create(:body=>"Invalid flare id F"+fid.to_s()+".", :to=>srcphone, :from=>twiliophone)			
			end
			messagepending=false
		end
		
		md=/^resp call f[0-9]+$/i.match(message.body)
		if messagepending and md!=nil
			disableFlareAndResponderBuild srcphone
			ok=@db.get_first_value("select count(*) from FLARES where flare_id="+fid+" and responder_id=(select responderid from RESPONDERS where srcphone='"+srcphone+"' and category=(select category from FLARES where flare_id="+fid+")")
			if ok>0
				#make conference call
			else
				@client.account.sms.messages.create(:body=>"Invalid flare id F"+fid.to_s()+".", :to=>srcphone, :from=>twiliophone)			
			end
			messagepending=false
		end
		
		md=/^sub \+[0-9]{11}$/i.match(message.body)
		if messagepending and md!=nil
			@db.execute "insert into SUBSCRIPTIONS (srcphone, subphone, approved, created_dt) values ('"+srcphone+"','"+message.body+"',0,'"+Time.now.to_s()+"')"
			@client.account.sms.messages.create(:body=>"Your subscription is pending approval by the owner of the subscribed phone number.", :to=>srcphone, :from=>twiliophone)
			@client.account.sms.messages.create(:body=>"The owner of phone number "+srcphone+" would like to subscribe to your FoneFlares.  Reply APPROVE "+srcphone+" to approve.", :to=>message.body)
		end
		
		md=/^approve \+[0-9]{11}$/i.match(message.body)
		if messagepending and md!=nil
			@db.execute "update SUBSCRIPTIONS set approved=1, updated_dt='"+Time.now.to_s()+"' where srcphone='"+message.body+"' and subphone='"+srcphone+"'"
			#@client.account.sms.messages.create(:body=>"You have approved "+message.body +" to receive all FoneFlares you submit.", :to=>message.body, :from=>twiliophone)
			#@client.account.sms.messages.create(:body=>"Your FoneFlare subscription to "+srcphone+" has been approved. You will receive a text message whenever this phone submits a FoneFlare.  Reply with UNSUB "+srcphone+" to unsubscribe.", :to=>message.body)
		end
				
		md=/^unsub \+[0-9]{11}$/i.match(message.body)
		if messagepending and md!=nil
			@db.execute("delete from SUBSCRIPTIONS where srcphone='"+srcphone+"' and subphone='"+message.body+"'")
			#@client.account.sms.messages.create(:body=>"You have unsubscribed from "+message.body +" FoneFlares.", :to=>srcphone)
		end
			
		
		if messagepending
			fs=@db.get_first_value("select ACTIVE from FLARES where SRCPHONE='" + srcphone + "' and ACTIVE>=2")
			if fs!=nil
				case fs.to_s()
				when "2"
					@db.execute("update FLARES set zip='"+message.body+"', active=3, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=2")
					@client.account.sms.messages.create(:body=>"What is the address or location code of your flare?", :to=>srcphone, :from=>twiliophone)
				when "3"
					@db.execute("update FLARES set location='"+message.body+"', active=4, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=3")
					@client.account.sms.messages.create(:body=>"What is the nature or category of your flare?", :to=>srcphone, :from=>twiliophone)
					c=@db.execute("select category_id, description from CATEGORIES order by category_id")
					body=""
					c.each do |row|
						body=body+row.join("\s")+"\n"
					end
					@client.account.sms.messages.create(:body=>body, :to=>srcphone, :from=>twiliophone)
				when "4"
					if message.body.to_i().to_s()==message.body
						@db.execute("update FLARES set category='"+message.body+"', active=5, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=4")
						@client.account.sms.messages.create(:body=>"Please enter a brief description of your flare.", :to=>srcphone, :from=>twiliophone)
					else
						@client.account.sms.messages.create(:body=>"Please enter a valid category number.", :to=>srcphone, :from=>twiliophone)
					end
				when "5"
					fid=@db.get_first_value("select flare_id from FLARES where srcphone='"+srcphone+"' and active=5")
					@db.execute("update FLARES set description='"+message.body+"', active=1, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=5")
					@client.account.sms.messages.create(:body=>"You have completed creating flare id F"+fid.to_s()+". Please record this responder id for future commands to FoneFlare." , :to=>srcphone, :from=>twiliophone)
				else
					disableFlareAndResponderBuild srcphone
					@client.account.sms.messages.create(:body=>"There was an error creating your flare.  Please reply with FLARE NEW to start over.", :to=>srcphone, :from=>twiliophone)
				end
				messagepending=false
			end
			rs=@db.get_first_value("select ACTIVE from RESPONDERS where SRCPHONE='" + srcphone + "' and ACTIVE>=2")
			if rs!=nil
				case rs.to_s()
					when "2"
						@db.execute("update RESPONDERS set zip='"+message.body+"', active=3, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=2")
						@client.account.sms.messages.create(:body=>"What is the category you can respond to?", :to=>srcphone, :from=>twiliophone)
						c=@db.execute("select category_id, description from CATEGORIES order by category_id")
						body=""
						c.each do |row|
							body=body+row.join("\s")+"\n"
						end
					@client.account.sms.messages.create(:body=>body, :to=>srcphone, :from=>twiliophone)
					when "3"
						if message.body.to_i().to_s()==message.body
							rid=@db.get_first_value("select responder_id from RESPONDERS where srcphone='"+srcphone+"' and active=3")
							@db.execute("update RESPONDERS set category="+message.body+", active=1, updated_dt='"+Time.now.to_s()+"' where srcphone='"+srcphone+"' and active=3")
							@client.account.sms.messages.create(:body=>"You have completed creating responder id R"+rid.to_s()+". Please record this responder id for future commands to FoneFlare." , :to=>srcphone, :from=>twiliophone)
						else
							@client.account.sms.messages.create(:body=>"Please enter a valid category number.", :to=>srcphone, :from=>twiliophone)
						end
				else
					disableFlareAndResponderBuild srcphone
					@client.account.sms.messages.create(:body=>"There was an error creating your responder.  Please reply with RESP AVAIL to start over.", :to=>srcphone, :from=>twiliophone)
				end
				messagepending=false
			end
		end

		if messagepending 
			body="ORIGINATOR: HELP,FLARE NEW,FLARE CANCEL [FID],FLARE CALL [FID]\nRESPONDER: RESP AVAIL [ZIP RADIUS],RESP QUIT,RESP [FID},RESP CALL [FID]"
			@client.account.sms.messages.create(:body=>body, :to=>srcphone, :from=>twiliophone)
			
			body="STOP to cancel all messages"
			@client.account.sms.messages.create(:body=>body, :to=>srcphone, :from=>twiliophone)

			messagepending=false
		end
	end
end

#process outbound messages
sql="
	select	a.flare_id,
			a.srcphone as flare_srcphone,
			c.description as flare_category,
			a.zip as flare_zip,
			a.location as flare_location,
			a.description as flare_description,
			a.created_dt as flare_created_dt,
			b.responder_id,
			b.srcphone as responder_srcphone
	from 	FLARES as a
			inner join RESPONDERS as b
				on b.zip=a.zip
					and b.category=a.category
					and ('"+(Time.now-15*60*60).to_s()+"'>(select max(created_dt) from COMMUNICATIONS as e where e.responder_id=b.responder_id)
						or not exists (select * from COMMUNICATIONS as f where f.responder_id=b.responder_id))
					and b.active=1
			inner join CATEGORIES as c
				on c.category_id=a.category
	where	a.active=1
			and not exists (select * from COMMUNICATIONS as d where d.flare_id=a.flare_id and d.responder_id=b.responder_id)
	order by b.srcphone,
			a.created_dt desc
	"
rs=@db.execute sql
resp_srcphone=""
resp_count=0
rs.each do |row|
	if resp_srcphone!=row[1]
		resp_srcphone=row[1]
		resp_count=0
	end
	if resp_count<5
		@client.account.sms.messages.create(:body=>"A "+row[2]+" flare has been created in your area. FlareID=F"+row[0].to_s()+".", :to=>row[8], :from=>twiliophone)
		@client.account.sms.messages.create(:body=>row[5], :to=>row[8], :from=>twiliophone)
		@db.execute "insert into COMMUNICATIONS (flare_id, responder_id, created_dt) values ("+row[0].to_s()+","+row[7].to_s()+",'"+Time.now.to_s()+"')"
		resp_count=resp_count+1
	end
end

sql="
	select	a.flare_id,
			a.srcphone	as flare_srcphone,
			b.srcphone	as subscriber_srcphone,
			c.description as category_description,
			a.description as flare_description
	from 	FLARES	as a
			inner join SUBSCRIPTIONS as b
				on b.subphone=a.srcphone
			inner join CATEGORIES as c
				on c.category_id=a.category
	where	not exists (select * from SUBSCRIPTIONCOMMUNICATIONS d where d.flare_id=a.flare_id and d.srcphone=b.srcphone) 
	"
rs=@db.execute sql
rs.each do |row|
	@client.account.sms.create(:body=>"A "+rs[3]+" was created by "+rs[1]+".", :to=>rs[2], :from=>twiliophone)
	@db.execute "insert into SUBSCRIPTIONCOMMUNICATIONS (flare_id, srcphone, created_dt) values ("+rs[0]+",'"+rs[2]+"','"+Time.now().to_s()+"')"
end

puts "FLARES TABLE"
rs=@db.execute("select * from FLARES")
rs.each do |row|
	puts row.join "\s"
end
puts ""
puts "RESPONDERS TABLE"
rs=@db.execute("select * from RESPONDERS")
rs.each do |row|
	puts row.join "\s"
end
puts ""

puts "COMMUNICATIONS TABLE"
rs=@db.execute "select * from COMMUNICATIONS"
rs.each do |row|
	puts row.join "\s"
end
puts ""

puts "SUBSCRIPTIONCOMMUNICATIONS TABLE"
rs=@db.execute "select * from SUBSCRIPTIONCOMMUNICATIONS"
rs.each do |row|
	puts row.join "\s"
end
puts ""

puts "ASSISTS TABLE"
rs=@db.execute "select * from ASSISTS"
rs.each do |row|
	puts row.join "\s"
end
puts ""