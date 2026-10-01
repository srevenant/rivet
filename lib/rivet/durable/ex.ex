{Core.DurableSupervisor,
  name: Core.DurableSupervisor,
  children: [
    Core.Mailer.Supervisor,
    Core.Scheduler,
    Stargaze.Reactor
  ],
  reporter: {Core.Mailer.Template.CriticalFail, :report}}
