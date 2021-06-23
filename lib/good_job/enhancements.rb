module GoodJob
  class Enhancements < Concurrent::Synchronization::Object
    def finished_at_column?
      if GoodJob::Job.column_names.include?(:finished_at)
        true
      else
        request_database_migration
        false
      end
    end

    def active_job_id_column?
      if GoodJob::Job.column_names.include?(:active_job_id)
        true
      else
        request_database_migration
        false
      end
    end

    def partially_lock_active_job_id?
      active_job_id_column? && all_jobs_have_active_job_id?
    end

    def fully_lock_active_job_id?
      active_job_id_column? && all_jobs_have_active_job_id? && notifiers_contain_version?
    end

    private

    def all_jobs_have_active_job_id?
      synchronize do
        return @_all_jobs_have_active_job_id if defined? @_all_jobs_have_active_job_id
        @_all_jobs_have_active_job_id = GoodJob::Job.unfinished.where(active_job_id: nil).any?
      end
    end

    def notifiers_contain_version?
      return false if Concurrent.on_jruby?

      synchronize do
        return @_notifier_contains_version if defined? @_notifier_contains_version
        query = <<~SQL.squish
          SELECT 1 AS one
          FROM pg_stat_activity
          WHERE application_name = $1;
        SQL
        @_notifier_contains_version = GoodJob::Job.connection.exec_query(query, '', [[nil, "GoodJob::Notifier"]]).any?
      end
    end

    def request_database_migration
      ActiveSupport::Deprecation.warn(<<~DEPRECATION)
        GoodJob has pending database migrations. To create the migration files, run:

            rails generate good_job:update

        To apply the migration files, run:

            rails db:migrate

      DEPRECATION
    end
  end
end
