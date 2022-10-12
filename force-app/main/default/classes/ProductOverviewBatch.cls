//
// Rolf Davidsson Fluido DK	20201009
// Important. Class should be executed with 1
// Database.executeBatch(new ProductOverviewBatch(), 1);
// 
// Scheduler ProductOverviewBatchScheduler
//


global class ProductOverviewBatch implements Database.Batchable<sObject> {
    global Integer ProcessedAccounts = 0;
    global Integer ProcessedAccountsWithContracts = 0;
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
         //0011t00000TeIZvAAN
         //0011q00000bBzSUAA0
         //0011t00000TcpskAAB
        //return Database.getQueryLocator('SELECT ID FROM Account where id=\''+'0011q00000bBzSUAA0'+'\'');
       	 return Database.getQueryLocator('SELECT ID FROM Account');
    }
    
    global void execute(Database.BatchableContext bc, List<Account> scope){
        Id AccountId=scope[0].Id;           
        
        String currencyCode = [SELECT Id, CurrencyIsoCode FROM Account WHERE Id = :accountId].CurrencyIsoCode;
        Map<Id, Product2> prdsWithId = new Map<Id, Product2>(
          [SELECT Id, Name FROM Product2 WHERE CurrencyIsoCode = :currencyCode AND IsActive = TRUE AND Product_Type__c='Clio Online Portal']
        );      
        
      //  list<ProductOverview__c> toDel = [select id from ProductOverview__c where account__c=:AccountId];
      //  delete toDel;
        
		list<SBQQ__Subscription__c> subRecs = [SELECT Id, SBQQ__Product__c, SBQQ__ProductName__c,Subscription_ACV__c,
                                            SBQQ__StartDate__c, SBQQ__EndDate__c, Is_Active__c FROM SBQQ__Subscription__c
                                            WHERE SBQQ__Account__c =:AccountId AND SBQQ__Product__r.Product_Type__c='Clio Online Portal'];
		ProcessedAccounts++;
        if (subRecs.isEmpty()) return;
        
        Map<Id, List<SBQQ__Subscription__c>> prdIdToSubsMap = new Map<Id, List<SBQQ__Subscription__c>>();
        for (SBQQ__Subscription__c s : subRecs) {
          if (prdIdToSubsMap.containsKey(s.SBQQ__Product__c)) {
            List<SBQQ__Subscription__c> subs = prdIdToSubsMap.get(s.SBQQ__Product__c);
            subs.add(s);
            prdIdToSubsMap.put(s.SBQQ__Product__c, subs);
          } else {
            prdIdToSubsMap.put(
              s.SBQQ__Product__c,
              new List<SBQQ__Subscription__c>{ s }
            );
          }
        }
        
        map<String,ProductOverview__c> productsOnAccount = new map<String,ProductOverview__c>();
        for (Product2 p : prdsWithId.values()) {
            ProductOverview__c A = new ProductOverview__c();
            A.No_Of_Active_Subscriptions__c=0;
            A.No_Of_Expired_Subscriptions__c=0;
            A.ExternalId__c =AccountId +'|'+p.Id;
            A.Product__c = p.Id;
            A.Account__c = AccountId;
            A.Sum_of_Subscription_Amount__c=0;
            productsOnAccount.put (AccountId +'|'+p.Id, A);
        }
        map<String,ProductOverview__c> objOnAccountProduct = new map<String,ProductOverview__c>();
        for (Product2 p : prdsWithId.values()) {
              ProductOverview__c po = productsOnAccount.get(AccountId +'|'+p.Id);
              if (prdIdToSubsMap.containsKey(p.Id)) {
                for (SBQQ__Subscription__c su : prdIdToSubsMap.get(p.Id)) {
                  po.Product_Name__c = su.SBQQ__ProductName__c;
                  po.Purchased__c = true;
                  // Highest End Date
                  // if (su.SBQQ__StartDate__c>po.Highest_Start_Date__c || po.Highest_Start_Date__c==null) po.Highest_Start_Date__c = su.SBQQ__StartDate__c; 
                    if (su.Is_Active__c==true) {
                      if (su.SBQQ__EndDate__c>po.Highest_Start_Date__c || po.Highest_Start_Date__c==null) po.Highest_Start_Date__c = su.SBQQ__EndDate__c;                     
                      if (su.SBQQ__StartDate__c<po.Lowest_Start_Date__c || po.Lowest_Start_Date__c==null) po.Lowest_Start_Date__c = su.SBQQ__StartDate__c;
                    }
                  po.Sum_of_Subscription_Amount__c =po.Sum_of_Subscription_Amount__c+su.Subscription_ACV__c;
                  if (Date.today() > su.SBQQ__EndDate__c || Date.Today() <su.SBQQ__StartDate__c) {
                      po.No_Of_Expired_Subscriptions__c++;     
                  }
                  if (Date.today() < su.SBQQ__EndDate__c && Date.Today() > su.SBQQ__StartDate__c) {
                       po.No_Of_Active_Subscriptions__c++;     
                  }
                }
              } else {
                po.Product_Name__c = p.Name;
                po.Purchased__c = false;
              }
              objOnAccountProduct.put(po.ExternalId__c,po);
        }   
        
        list<ProductOverview__c> target = new list<ProductOverview__c>();
        for (Product2 p : prdsWithId.values()) {
            target.add(productsOnAccount.get(AccountId +'|'+p.Id));
        }              
        ProcessedAccountsWithContracts++;
        if (!target.isEmpty()) upsert target ExternalId__c;
        
        
        list<SBQQ__Subscription__c> forUpd = new list<SBQQ__Subscription__c>();
        for (ProductOverview__c pv:target) {
            try {
                for (SBQQ__Subscription__c su : prdIdToSubsMap.get(pv.Product__c)) {                
                    system.debug('getting:'+pv.ExternalId__c);
                    su.Product_Overview__c = objOnAccountProduct.get(pv.ExternalId__c).Id;
                    forUpd.add(su);
                }
            }
                catch (exception e) {
                    system.debug('HANDLED ERROR:'+e.getMessage());
            }
                                
        }
        if (!forUpd.isEmpty()) update forUpd;


    }

 global void finish(Database.BatchableContext bc){
     system.debug('ProductOverviewBatch ====================================================');
     system.debug('ProductOverviewBatch completed. Processed accounts without contracts'+ProcessedAccounts);
     system.debug('ProductOverviewBatch completed. Processed accounts with contracts '+ProcessedAccountsWithContracts);
     system.debug('ProductOverviewBatch ====================================================');
 }    

}