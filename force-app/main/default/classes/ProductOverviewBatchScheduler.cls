global class ProductOverviewBatchScheduler implements Schedulable  {
   global void execute(SchedulableContext ctx) {
      ProductOverviewBatch p = new ProductOverviewBatch();
      database.executeBatch(p,1);
   }   
}