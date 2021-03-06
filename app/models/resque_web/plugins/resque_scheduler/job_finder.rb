module ResqueWeb
  module Plugins
    module ResqueScheduler
      # This class exists to find jobs which match a search term. They may be
      # being processed, in the queue, or delayed.
      class JobFinder
        # The search term that the user entered.
        attr_accessor :search_term

        # @param [String] search_term
        def initialize(search_term = nil)
          @search_term = search_term || ''
          @search_term.downcase!
        end

        # Finds all jobs that match the search term supplied when the class was
        # initialized.
        #
        # @return [Array]
        def find_jobs
          return [] if search_term.empty?
          results = []
          results += working_jobs_where_class_name_contains_search_term
          results += delayed_jobs_where_class_name_contains_search_term
          results + queued_jobs_where_class_name_matches_search_term
        end

        protected

        def working_jobs_where_class_name_contains_search_term
          WorkingJobFinder.new(search_term).find_jobs
        end

        def delayed_jobs_where_class_name_contains_search_term
          delayed_job_timestamps.inject([]) do |jobs, timestamp|
            jobs + delayed_jobs_for_timestamp_that_match_search_term(timestamp)
          end
        end

        def delayed_jobs_for_timestamp_that_match_search_term(timestamp)
          delayed_jobs_for_timestamp(timestamp).select do |job|
            job['class'].downcase.include?(search_term) &&
              job.merge!('where_at' => 'delayed') &&
              job.merge!('timestamp' => timestamp)
          end
        end

        def delayed_job_timestamps
          Resque.delayed_queue_peek(0, schedule_size)
        end

        def schedule_size
          Resque.delayed_queue_schedule_size
        end

        def delayed_jobs_for_timestamp(timestamp)
          Resque.delayed_timestamp_peek(timestamp,
                                        0,
                                        number_of_delayed_jobs_at(timestamp))
        end

        def number_of_delayed_jobs_at(timestamp)
          Resque.delayed_timestamp_size(timestamp)
        end

        def queued_jobs_where_class_name_matches_search_term
          Resque.queues.inject([]) do |results, queue|
            results + queued_jobs_from_queue(queue).select do |job|
              job['class'].downcase.include?(search_term) &&
                job.merge!('queue' => queue) &&
                job.merge!('where_at' => 'queued')
            end
          end
        end

        def queued_jobs_from_queue(queue)
          jobs = Resque.peek(queue, 0, Resque.size(queue))
          if jobs.is_a? Array
            jobs
          else
            [jobs]
          end
        end
      end
    end
  end
end
