trigger OrderTrigger on Order (after update) {
	TriggerDispatcher.run(new OrderTriggerHandler());
}