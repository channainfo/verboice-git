module Ext
	class ReminderSchedule < ExtActiveRecord
		include ActiveModel::Validations

		DEFAULT_DATE_FORMAT  = '%Y-%m-%d'
 		DEFAULT_DATE_TIME_FORMAT  = '%Y-%m-%d %H:%M'

		serialize :queue_call_id
		serialize :conditions, Array

		#TODO : alias attribute for :date_time
		validates :client_start_date, :"ext/date" => {:date_format => Ext::ReminderSchedule::DEFAULT_DATE_FORMAT, :field => :start_date }

		validates :time_from, :presence => true
		validates :time_to, :presence => true

		validates :call_flow_id, :presence => true
		validates :channel_id, :presence => true
		validates :days, :presence => true , :if => Proc.new {|record| record.schedule_type == ReminderSchedule::TYPE_DAILY }
		validates :recursion, :presence => true , :if => Proc.new {|record| record.schedule_type == ReminderSchedule::TYPE_DAILY }

		belongs_to :call_flow
		belongs_to :schedule
		belongs_to :channel

		belongs_to :project
		assign_has_many_to "Project", :ext_reminder_schedules, :class_name => "Ext::ReminderSchedule"

		TYPE_ONE_TIME = 0
		TYPE_DAILY   = 1
		# TYPE_WEEKLY  = 2

		attr_accessor :client_start_date

		before_save   :filter_date_time
		after_create  :create_queues_call
		after_destroy :remove_queues

		def create_queues_call
			process reminder_phone_book_type.reminder_phone_books, DateTime.now.utc if reminder_phone_book_type
		end

		def update_queues_call
			remove_queue_call
			create_queues_call
		end

		def remove_queues
			begin
				queues = QueuedCall.find queue_call_id
				queues.each do |queue|
					queue.destroy
				end
			rescue Exception => e	
				p e.message
			end
		end

		def remove_queue_call
			if queue_call_id
				remove_queues
				self.queue_call_id = []
				self.save
			end
		end

		def self.schedule project_id, at_time
			project = Project.find(project_id)
			reminder_schedules  = project.ext_reminder_schedules

			reminder_schedules.each do |reminder|
				phone_books = reminder.reminder_phone_book_type.reminder_phone_books if reminder.reminder_phone_book_type
				reminder.process phone_books, at_time if phone_books
			end
		end

		# run at Y-m-d , 00:00
		def process phone_books, at_time
			if schedule_type == ReminderSchedule::TYPE_ONE_TIME
				if start_date.equal?(at_time.to_date)
					from_date_time = DateTimeParser.parse("#{start_date.to_s} #{time_from}", ReminderSchedule::DEFAULT_DATE_TIME_FORMAT, timezone)
					to_date_time = DateTimeParser.parse("#{start_date.to_s} #{time_to}", ReminderSchedule::DEFAULT_DATE_TIME_FORMAT, timezone)
					if from_date_time.greater_or_equal?(at_time) or to_date_time.greater_or_equal?(at_time)
						phone_numbers = callers_matches_conditions phone_books
						if not phone_numbers.empty?
							enqueued_call(phone_numbers, at_time)
						end
					end
				end
			else
				if at_time.to_date.greater_or_equal? start_date
					if in_schedule_day? at_time.wday
						phone_numbers = callers_matches_conditions phone_books
						if not phone_numbers.empty?
							number_of_day_period = recursion * 7
							ref_day = ReminderSchedule.ref_offset_date self.days, self.start_date, at_time
					  	enqueued_call(phone_numbers, at_time) if (ref_day && ReminderSchedule.in_period?(at_time, ref_day, number_of_day_period))
						end
					end
				end
			end
		end

		def self.in_period? now, ref_date, number_day_period
			current = DateTime.new(now.year, now.month, now.day)
			offset = DateTime.new(ref_date.year, ref_date.month, ref_date.day)

			number_days = (current.to_i - offset.to_i)/(24*3600)
			number_days % number_day_period == 0
		end

		def self.ref_offset_date days, start_date, current
			#TODO add test
			days_list = self.days_list days, start_date
			days_list[current.wday.to_s]
		end

		def self.days_list days, start_date
			days_list = {}
			days.split(",").each  do |wday|
				diff = (start_date.wday - wday.to_i).abs 
				if start_date.wday > wday.to_i
					days_list[wday] = start_date - diff.days
				else
					days_list[wday] = start_date + diff.days	
				end
			end if days
			days_list
		end

		def call_options at_time
			call_time_string = "#{at_time.to_string(Date::DEFAULT_FORMAT)} #{time_from}"
			not_before = DateTimeParser.parse(call_time_string, ReminderSchedule::DEFAULT_DATE_TIME_FORMAT, timezone)

			options = { 
				:call_flow_id => self.call_flow_id,
				:project_id => self.project_id,
				:time_zone => self.timezone,
				:not_before => not_before
			}

			options[:schedule_id] = self.schedule_id  if self.schedule_id
			options
		end

		def enqueued_call addresses, at_time
			options = call_options at_time
			queues = []
			addresses.each do |address|
				call_log = self.channel.call(address, options)
				raise call_log.fail_reason if call_log.fail_reason
				queue =  QueuedCall.find_by_call_log_id(call_log.id) 
				queues << queue.id if queue
			end
			self.queue_call_id = queues
			self.save
			queues
		end

		def in_schedule_day? day
			days.nil? ? false : days.include?(day.to_s) 
		end

		def filter_date_time
			self.start_date = Ext::DateParser.parse(self.client_start_date) unless client_start_date.nil?
		end
		
		def client_start_date
			@client_start_date
		end

		def client_start_date=(val)
			@client_start_date = val
		end

		def schedule_description
			time = self.start_date.in_time_zone self.timezone
			time_string  = ReminderSchedule.filter_time time
			start_string = ReminderSchedule.filter_start time

			if self.schedule_type == ReminderSchedule::TYPE_ONE_TIME
			   "Call at #{time_string} on #{start_string} "
			else
				day_string   = ReminderSchedule.filter_day(self.days)
				# if self.schedule_type == ReminderSchedule::TYPE_DAILY
			 #   		"Start from #{start_string} Every week on #{day_string}, Call at #{time_string}"
				# elsif self.schedule_type == ReminderSchedule::TYPE_WEEKLY
					"Start from #{start_string} Every #{self.recursion} weeks on #{day_string}. Call at #{time_string}"
				# end
			end	
		end

		def self.filter_start ar_time
			ar_time.to_datetime.strftime("%m/%d/%Y") 
		end

		def self.filter_time ar_time
			ar_time.to_datetime.strftime("%I:%M %P") 
		end

		def self.filter_day days_format
			d = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]	
			days_format.split(",").map{|num| d[num.to_i]}.join(", ")	
		end

		def has_conditions?
			exists = false
			exists = true if !conditions.nil? && !conditions.empty?
			exists
		end

		def callers_matches_conditions phone_books
			phone_numbers = []
			if has_conditions?
				phone_books.each do |phone_book|
					contact = Contact.where(:address => phone_book.phone_number, :project_id => project.id).last
					phone_numbers.push phone_book.phone_number if contact and contact.evaluate? conditions
				end
			else
				phone_numbers = phone_books.map { |x| x.phone_number}
			end
			phone_numbers
		end

	end

end
