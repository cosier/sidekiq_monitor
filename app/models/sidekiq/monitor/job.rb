module Sidekiq
  module Monitor
    class Job
      include Mongoid::Document
      include Mongoid::Timestamps

      attr_accessor :args, :class_name,
                      :enqueued_at, :finished_at, :jid,
                      :name, :queue, :result, :retry,
                      :started_at, :status

      # serialize :args
      # serialize :result

      field :class_name,   type: String
      field :queue,        type: String
      field :jib,          type: String
      field :retry,        type: Boolean
      field :enqueued_at,  type: DateTime
      field :started_at,   type: DateTime
      field :status,       type: String
      field :name,         type: String
      field :args,         type: Object
      field :result,       type: Object

      after_destroy :delete_sidekiq_job

      @statuses = [
        'queued',
        'running',
        'complete',
        'failed'
      ]

      class << self
        attr_reader :statuses

        def add_status(status)
          @statuses << status
          @statuses.uniq!
        end

        def find_by_jid(id)
          where(jib: id).first
        end

        def destroy_by_queue(queue, conditions={})
          jobs = where(conditions).where(status: 'queued', queue: queue).destroy_all
          jids = jobs.map(&:jid)
          sidekiq_queue = Sidekiq::Queue.new(queue)
          sidekiq_queue.each do |job|
            job.delete if conditions.blank? || jids.include?(job.jid)
          end
          jobs
        end
      end

      def sidekiq_item
        job = sidekiq_job
        job ? job.item : nil
      end

      def sidekiq_job
        sidekiq_queue = Sidekiq::Queue.new(queue)
        sidekiq_queue.each do |job|
          return job if job.jid == jid
        end
        nil
      end

      def delete_sidekiq_job
        return true unless status == 'queued'
        job = sidekiq_job
        job.delete if job
      end
    end
  end
end
