require 'new_relic/agent/instrumentation/controller_instrumentation'

DependencyDetection.defer do
  @name = :chore

  depends_on do
    defined?(::Chore::CLI) && !NewRelic::Agent.config[:disable_chore]
  end

  executes do
    ::NewRelic::Agent.logger.info 'Installing NewRelic instrumentation'
  end

  executes do

    module Chore
      module NewRelicInstrumentation
        include NewRelic::Agent::Instrumentation::ControllerInstrumentation

        def perform(*args)
          begin
            Chore.logger.debug "Logging #{self.name}#perform to NewRelic"
            perform_action_with_newrelic_trace(:name => 'perform',
                                 :class_name => self.name,
                                 :category => 'OtherTransaction/ChoreJob') do
              super(*args)
            end
          ensure
            NewRelic::Agent.shutdown if NewRelic::LanguageSupport.can_fork?
          end
        end
      end
    end

    module NewRelic
      module Agent
        module Instrumentation
          module ChoreInstrumentHook
            def payload_class(message)
              klass = super
              klass.instance_eval do
                extend ::Chore::NewRelicInstrumentation
              end
              klass
            end
          end
        end
      end
    end

    ::Chore::Worker.class_eval do
      def self.new(*args)
        super(*args).extend NewRelic::Agent::Instrumentation::ChoreInstrumentHook
      end
    end

    if NewRelic::LanguageSupport.can_fork?
      ::Chore.add_hook(:before_first_fork) do
        NewRelic::Agent.manual_start(:dispatcher   => :resque,
                                     :sync_startup => true,
                                     :start_channel_listener => true,
                                     :report_instance_busy => false)
      end

      ::Chore.add_hook(:before_fork) do |worker|
        NewRelic::Agent.register_report_channel(worker.object_id)
      end

      ::Chore.add_hook(:after_fork) do |worker|
        NewRelic::Agent.after_fork(:report_to_channel => worker.object_id)
      end
    end
  end
end

# call this now so it is memoized before potentially forking worker processes
NewRelic::LanguageSupport.can_fork?
