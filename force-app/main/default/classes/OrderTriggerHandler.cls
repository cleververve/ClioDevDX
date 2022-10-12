public without sharing class OrderTriggerHandler implements ITriggerHandler {
	@TestVisible private static Boolean triggerBypass = false;
    
    public Boolean isDisabled() {
        return triggerBypass;
    }
    
    public void beforeInsert(List<SObject> newItems) {
        // This is a placeholder for handlers
    }

    public void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // This is a placeholder for handlers
    }

    public void beforeDelete(Map<Id, SObject> oldItems) {
        // This is a placeholder for handlers
    }

    public void afterInsert(Map<Id, SObject> newItems) {
        // This is a placeholder for handlers
    }

    public void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        createInvoiceLinesForActivatedOrders((Map<Id, Order>) newItems, (Map<Id, Order>) oldItems);
    }

    public void afterDelete(Map<Id, SObject> oldItems) {
        // This is a placeholder for handlers
    }

    public void afterUndelete(Map<Id, SObject> oldItems){
        // This is a placeholder for handlers
    }
    
    private void createInvoiceLinesForActivatedOrders(Map<Id, Order> newOrders, Map<Id, Order> oldOrders) {
        Map<Id, Order> activatedOrders = filterActivatedOrders(newOrders, oldOrders);
        List<OrderItem> filteredOrderProducts = filterClioOnlinePortalProducts(activatedOrders);
        System.debug('Found ' + activatedOrders.size() + ' activatedOrders and ' + filteredOrderProducts.size() + ' filteredOrderProducts');
        if (!filteredOrderProducts.isEmpty()) {
        	createInvoiceLines(filteredOrderProducts);
        }
    }
    
    private Map<Id, Order> filterActivatedOrders(Map<Id, Order> newOrders, Map<Id, Order> oldOrders) {
        Map<Id, Order> activatedOrders = new Map<Id, Order>();
        for (Order o : newOrders.values()) {
            
            if (o.Sent_for_Invoicing_Date_Stamp__c	!= null) {
                System.debug('Skipping creation of invoice lines becase "Sent for Invoicing Date Stamp" is not empty.');
            }
            if (o.Sent_for_Invoicing_Date_Stamp__c	== null &&
                o.Status == Constants.ORDER_STATUS_SENT_FOR_INVOICING && 
                oldOrders.get(o.Id).Status != Constants.ORDER_STATUS_SENT_FOR_INVOICING) {
                    activatedOrders.put(o.Id, o);
            }
        }
        return activatedOrders;
    }
    
    private void createInvoiceLines(List<OrderItem> orderProducts) {
        List<Invoice_Line__c> newInvoiceLines = new List<Invoice_Line__c>();
        for (OrderItem oi : orderProducts) {
            if (oi.SBQQ__QuotedQuantity__c > 0) {
            	newInvoiceLines.addAll(preparePositiveInvoiceLinesForOrderProduct(oi));
            } else {
                newInvoiceLines.addAll(prepareNegativeInvoiceLinesForOrderProduct(oi));
            }
        }
        insert newInvoiceLines;
    }
    
    private List<Invoice_Line__c> preparePositiveInvoiceLinesForOrderProduct(OrderItem oi) {
        return prepareInvoiceLinesForOrderProduct(oi, false);
    }
    
    @TestVisible
    private List<Invoice_Line__c> prepareNegativeInvoiceLinesForOrderProduct(OrderItem oi) {
        return prepareInvoiceLinesForOrderProduct(oi, true);
    }
    
    private List<Invoice_Line__c> prepareInvoiceLinesForOrderProduct(OrderItem oi, Boolean isNegative) {
        List<Invoice_Line__c> newInvoiceLines = new List<Invoice_Line__c>();
        Date invoiceLineStartDate = null;
        Date invoiceLineEndDate = null;
        Integer monthsCountPerInvoiceLine = getMonthsCountBasingOnBillingFrequency(oi);
        Integer i = 1;
        do {
            Invoice_Line__c newIL = new Invoice_Line__c();
            newIL.Item_Serie_Number__c = i;
            newIL.CurrencyIsoCode = oi.Order.CurrencyIsoCode;
            newIL.Sales_Type_Code__c = invoiceLineStartDate == null ? oi.Sales_Type_Code__c : Constants.SALES_TYPE_CODE_REBILL;
            newIL.Blanket_Order_Delete__c = invoiceLineStartDate != null && isNegative ? Date.today() : null;
            invoiceLineStartDate = invoiceLineStartDate == null ? oi.ServiceDate : isNegative ? invoiceLineEndDate.addDays(1) : invoiceLineStartDate.addMonths(monthsCountPerInvoiceLine);
            newIL.Start_Date__c = invoiceLineStartDate;
            invoiceLineEndDate = isNegative ? getEndDateForNegative(invoiceLineStartDate, invoiceLineEndDate, oi.EndDate, monthsCountPerInvoiceLine) : getEndDateForPositive(oi.EndDate, invoiceLineStartDate, monthsCountPerInvoiceLine);
            newIL.End_Date__c = invoiceLineEndDate;
            newIL.Shipment_Date__c = i == 1 ? getFirstDateIfNullThenSecond(oi.Order.Clio_First_invoice_date__c, oi.Order.ActivatedDate.date()) : newIL.Start_Date__c;
            newIL.Quote_Line__c = oi.SBQQ__QuoteLine__c;
            newIL.Product__c = oi.Product2Id;
            newIL.Order__c = oi.OrderId;
            newIL.Order_Product__c = oi.Id;
            newIL.Yearly_Product_Order_Value__c = oi.SBQQ__QuoteLine__c != null ? oi.SBQQ__QuoteLine__r.Yearly_Order_Value__c : null;
            newIL.Total_Discount__c = oi.SBQQ__QuoteLine__c != null ? oi.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c : null;
            newIL.Partner_Discount__c = oi.SBQQ__QuoteLine__c != null && oi.SBQQ__QuoteLine__r.SBQQ__Quote__c != null ? oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PartnerDiscount__c : null;
            newIL.Total_Discount_incl_Partner__c = oi.SBQQ__QuoteLine__c != null ? oi.SBQQ__QuoteLine__r.Total_Discount_incl_Partner__c : null;
            newInvoiceLines.add(newIL);
            i += 1;
        } while(oi.EndDate > invoiceLineStartDate.addMonths(monthsCountPerInvoiceLine).addDays(-1));
        return newInvoiceLines;
    }
    
    private Date getFirstDateIfNullThenSecond(Date firstDate, Date secondDate) {
        if (firstDate == null) {
            return secondDate;
        }
        return firstDate;
    }
    
    private Integer getMonthsCountBasingOnBillingFrequency(OrderItem oi) {
        Integer monthsCount = 12; // default is 1 year per Invoice Line
        if (oi.SBQQ__QuoteLine__c != null && oi.SBQQ__QuoteLine__r.SBQQ__Quote__c != null) {
            switch on oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__BillingFrequency__c {
                when 'Semiannual' {
            		monthsCount = 6;
                } when 'Kvartalsvis' {
                    monthsCount = 3;
                } when 'One Time' {
                    monthsCount = 1200; // 100 years
                }
            }
        }
        return monthsCount;
    }
    
    private Date getEndDateForPositive(Date orderProductEndDate, Date invoiceLineStartDate, Integer monthsCountPerInvoiceLine) {
        if (orderProductEndDate > invoiceLineStartDate.addMonths(monthsCountPerInvoiceLine).addDays(-1)) {
            return invoiceLineStartDate.addMonths(monthsCountPerInvoiceLine).addDays(-1);
        } else {
            return orderProductEndDate;
        }
    }
    
    private Date getEndDateForNegative(Date lastInvoiceLineStartDate, Date lastInvoiceLineEndDate, Date orderProductEndDate, Integer monthsCountPerInvoiceLine) {
        if (lastInvoiceLineEndDate == null) {
            lastInvoiceLineEndDate = orderProductEndDate;
            while (lastInvoiceLineEndDate > lastInvoiceLineStartDate) {
                lastInvoiceLineEndDate = lastInvoiceLineEndDate.addMonths(-monthsCountPerInvoiceLine);
            }
        }
        return lastInvoiceLineEndDate.addMonths(monthsCountPerInvoiceLine);
    }
    
    @TestVisible
    private List<OrderItem> filterClioOnlinePortalProducts(Map<Id, Order> orders) {
        List<Order> ordersWithRelations = [
            SELECT 
                (SELECT Id,
                Order.ActivatedDate,
                Order.CurrencyIsoCode,
                Order.Clio_First_invoice_date__c,
                Sales_Type_Code__c,
                ServiceDate,
                EndDate,
                Product2Id,
                OrderId,
                SBQQ__QuotedQuantity__c,
                SBQQ__QuoteLine__r.Yearly_Order_Value__c,
                SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PartnerDiscount__c,
                SBQQ__QuoteLine__r.Total_Discount_incl_Partner__c,
                SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__BillingFrequency__c,
                SBQQ__QuoteLine__c
                FROM OrderItems
                WHERE Product2.Product_Type__c = :Constants.PRODUCT_TYPE_CLIO_ONLINE_PORTAL)
            FROM Order
            WHERE Id IN :orders.keyset()
        ];
        
        List<OrderItem> filteredItems = new List<OrderItem>();
        for (Order o : ordersWithRelations) {
            filteredItems.addAll(o.OrderItems);
        }
        return filteredItems;
    }
}