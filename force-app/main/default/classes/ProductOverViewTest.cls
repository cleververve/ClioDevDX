@istest
public class ProductOverViewTest {

	static testmethod void testScheduler() {
	Id pricebookId = Test.getStandardPricebookId();
			Account acc = new Account();
			acc.Name = 'test';
			acc.Type = 'Prospect';
			acc.CurrencyIsoCode = 'DKK';
			acc.BillingCountry = 'Denmark';
			acc.Country_Code__c = 'DK';
			acc.Market__c = 'Denmark';
			insert acc;
	Product2 prod = new Product2();
			prod.Country_Code__c = 'DK';
			prod.CurrencyIsoCode = 'DKK';
			prod.Family = 'Portal';
			prod.IsActive = true;
			prod.Level__c = 'Indskolning';
			prod.Name = 'Billedkunstfaget.dk (1.-2. klasse)';
			prod.NAV_Type__c = 'Item';
			prod.Navision_Prod_No__c = 23100;
			prod.Product_Category__c = 'Portal';
			prod.Product_No__c = 391;
			prod.Product_Type__c = 'Clio Online Portal';
			prod.SBQQ__SubscriptionPricing__c = 'Fixed Price';
			prod.SBQQ__SubscriptionTerm__c = 12;
			prod.ProductCode = 'BKIN';
			insert prod;
			
	SBQQ__Subscription__c sub = new SBQQ__Subscription__c();
			sub.SBQQ__Account__c=acc.Id;
			sub.SBQQ__Product__c = prod.Id;
        	sub.SBQQ__Quantity__c=1;
			//sub.SBQQ__StartDate__c=date.today().adddays(-5);
			//sub.SBQQ__EndDate__c=date.today().adddays(5);
			insert sub;

			test.starttest();
			ProductOverviewBatchScheduler myClass = new ProductOverviewBatchScheduler ();   
			String chron = '0 0 23 * * ?';        
			system.schedule('Test Sched', chron, myClass);
			test.stopTest();
		}
}