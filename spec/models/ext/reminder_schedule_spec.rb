require 'spec_helper'

describe Ext::ReminderSchedule  do
	before(:each) do
		@project = Project.make
        @call_flow= CallFlow.make :project_id => @project.id
        @channel = Channels::Custom.make :call_flow => @call_flow
	end

	describe "Create new reminder schedule" do
	  before(:each) do

	  	@valid = {
	  		:name => "reminder 1",
	  		:schedule_type => Ext::ReminderSchedule::TYPE_ONE_TIME,
	  		:project_id => @project.id,
	  		:call_flow_id => @call_flow.id,
	  		:client_start_date => "10/25/2012 09:20",
	  		:channel_id => @channel.id,
	  		:schedule => nil
	  	}
	  end	

	  it "should create a reminder schedule with valid attribute" do 
		reminder_schedule = Ext::ReminderSchedule.new @valid
		result = reminder_schedule.save
		result.should eq true

		reminder_schedule.date_format_for_calendar.should eq "10/25/2012 09:20"
		reminder_schedule.schedule_type.should eq Ext::ReminderSchedule::TYPE_ONE_TIME
	  end

	  it "should require name" do
	  	invalid = @valid.merge(:name => "")	
	    reminder_schedule  =  Ext::ReminderSchedule.new invalid
	    reminder_schedule.save().should eq false
	  end

	  it "should require start_date with valid format" do
	     invalid = @valid.merge(:client_start_date => "")	
	     reminder_schedule  =  Ext::ReminderSchedule.new invalid
	     reminder_schedule.save().should eq false
	  end	

	  it "should require days if type is diff from onetime " do
	  	invalid = @valid.merge(:days => "", :schedule_type => Ext::ReminderSchedule::TYPE_WEEKLY )	
	    reminder_schedule  =  Ext::ReminderSchedule.new invalid
	    reminder_schedule.save().should eq false
	  end

	end

	describe "ReminderSchedule.filter_day"  do
	   it "should return a day string of given day" do

	   		days = [
	   			{ :format => "0,1,2", :result => "Sun, Mon, Tue" },
	   			{ :format => "2,3", :result => "Tue, Wed" },
	   			{ :format => "6", :result => "Sat" }
	   		].each do |elm|
	   			result = Ext::ReminderSchedule.filter_day elm[:format]
	   			result.should eq elm[:result]
	   		end
	   end
	end

	describe "ReminderSchedule.in_schedule_day? " do
		it "should tell if a datetime in days of reminder schedule days" do
			days = "0,2,3"
			Ext::ReminderSchedule.in_schedule_day?(days, DateTime.new(2012,10,7).wday).should eq true
			Ext::ReminderSchedule.in_schedule_day?(days, DateTime.new(2012,10,8).wday).should eq false
			Ext::ReminderSchedule.in_schedule_day?(days, DateTime.new(2012,10,9).wday).should eq true
			Ext::ReminderSchedule.in_schedule_day?(days, DateTime.new(2012,10,10).wday).should eq true
			Ext::ReminderSchedule.in_schedule_day?(days, DateTime.new(2012,10,11).wday).should eq false


		end
	end 


	describe "ReminderSchedule.alert_call to user in phonebook" do
		before(:each) do
			@phone_books = []
			
			10.times.each do
				@phone_books << Ext::ReminderPhoneBook.make
			end
		end
		describe "ReminderSchedule.process_reminder one time " do

			it "should call to all phone book of the project" do
				reminder_one_time = Ext::ReminderSchedule.make(:schedule_type => Ext::ReminderSchedule::TYPE_ONE_TIME,
													  		:project_id => @project.id,
													  		:call_flow_id => @call_flow.id,
													  		:channel_id => @channel.id,
													  		:schedule => nil,
													  		:client_start_date => Ext::Util.date_time_to_str(DateTime.now)
													  		)

				Ext::ReminderSchedule.should_receive(:call)
				Ext::ReminderSchedule.process_reminder(reminder_one_time, @phone_books, DateTime.now)

			end

			it "should not call to any phone book " do

				[ Ext::ReminderSchedule.make(:schedule_type => Ext::ReminderSchedule::TYPE_ONE_TIME,
													  		:project_id => @project.id,
													  		:call_flow_id => @call_flow.id,
													  		:channel_id => @channel.id,
													  		:schedule => nil,
													  		:client_start_date => Ext::Util.date_time_to_str(DateTime.now-1.day)
													  		),
				Ext::ReminderSchedule.make(:schedule_type => Ext::ReminderSchedule::TYPE_ONE_TIME,
													  		:project_id => @project.id,
													  		:call_flow_id => @call_flow.id,
													  		:channel_id => @channel.id,
													  		:schedule => nil,
													  		:client_start_date => Ext::Util.date_time_to_str(DateTime.now + 1.day)
													  		) 
				].each do |reminder|
					Ext::ReminderSchedule.should_receive(:call).never
					Ext::ReminderSchedule.process_reminder(reminder, @phone_books, DateTime.now)
				end
				
			end
		end

		describe "ReminderSchedule.process_reminder daily " do
		  before(:each) do
		  	@reminder_daily = Ext::ReminderSchedule.make(    :schedule_type => Ext::ReminderSchedule::TYPE_DAILY,
													  		:project_id => @project.id,
													  		:call_flow_id => @call_flow.id,
													  		:channel_id => @channel.id,
													  		:schedule => nil,
													  		:days => "0,3,4,6" ,
													  		:client_start_date => "10/15/2012 00:00"
													  		)
		  end

		  it "should not call at all " do

		  	[ DateTime.new(2012, 10, 7),
		  	  DateTime.new(2012, 10, 14), 
		  	  DateTime.new(2012, 10, 15) , 
		  	  DateTime.new(2012, 10, 16) , 
		  	  DateTime.new(2012, 10, 19) 
		  	].each do |current_date|
			    Ext::ReminderSchedule.should_receive(:call).never
				Ext::ReminderSchedule.process_reminder(@reminder_daily, @phone_books, current_date)
			end
		  end

		  it "should call to all phone books" do
		  	[ DateTime.new(2012, 10, 17), 
		  	  DateTime.new(2012, 10, 18) , 
		  	  DateTime.new(2012, 10, 20) 
		  	].each do |current_date|
			    Ext::ReminderSchedule.should_receive(:call)
				Ext::ReminderSchedule.process_reminder(@reminder_daily, @phone_books, current_date)
			end
		  end
		end

		describe "ReminderSchedule.process_reminder weekly " do

			describe "ReminderSchedule.process_reminder weekly first run " do
				before(:each ) do
					@reminder_weekly = Ext::ReminderSchedule.make(	:schedule_type => Ext::ReminderSchedule::TYPE_WEEKLY,
															  		:project_id => @project.id,
															  		:call_flow_id => @call_flow.id,
															  		:channel_id => @channel.id,
															  		:schedule => nil,
															  		:days => "0,1,2,6",
															  		:recursion => 3,
															  		:client_start_date => "10/15/2012 00:00",
															  		:next_run => false
														  		)
				end

				it "should not call at all " do 
				  [ 
				  	 DateTime.new(2012, 10, 14),
				  	 DateTime.new(2012, 10, 17), 
				  	 DateTime.new(2012, 10, 18) , 
				  	 DateTime.new(2012, 10, 19)  
				  ].each do |current_date|
				  		Ext::ReminderSchedule.should_receive(:call).never
						Ext::ReminderSchedule.process_reminder(@reminder_weekly, @phone_books, current_date)
					end
				end

				it "should call to all phone books" do 
				  [ DateTime.new(2012, 10, 15),
				  	DateTime.new(2012, 10, 16), 
				  	DateTime.new(2012, 10, 20)
				  ].each do |current_date|
				  		Ext::ReminderSchedule.should_receive(:call)
						Ext::ReminderSchedule.process_reminder(@reminder_weekly, @phone_books, current_date)
					end
				end
			end



			describe "ReminderSchedule.process_reminder weekly next run " do
				before(:each ) do
					@reminder_weekly = Ext::ReminderSchedule.make(	:schedule_type => Ext::ReminderSchedule::TYPE_WEEKLY,
															  		:project_id => @project.id,
															  		:call_flow_id => @call_flow.id,
															  		:channel_id => @channel.id,
															  		:schedule => nil,
															  		:days => "0,1,2,6",
															  		:recursion => 3,
															  		:client_start_date => "10/15/2012 00:00",
															  		:next_run => true
														  		)
				end

				it "should not call at all " do 
				  [ 
				  	 # DateTime.new(2012, 10, 14),
				  	 # DateTime.new(2012, 10, 19) ,
				  	 # DateTime.new(2012, 10, 21) ,
				  	 # DateTime.new(2012, 10, 22) ,
				  	 # DateTime.new(2012, 10, 23) ,

				  ].each do |current_date|
				  		Ext::ReminderSchedule.should_receive(:call).never
						Ext::ReminderSchedule.process_reminder(@reminder_weekly, @phone_books, current_date)
					end
				end

				it "should call to all phone books" do 
				  [ DateTime.new(2012, 11, 4),
				  	# DateTime.new(2012, 11, 5), 
				  	# DateTime.new(2012, 11, 10)
				  ].each do |current_date|
				  		Ext::ReminderSchedule.should_receive(:call)
						Ext::ReminderSchedule.process_reminder(@reminder_weekly, @phone_books, current_date)
					end
				end
			end		



		end


	end









	

end