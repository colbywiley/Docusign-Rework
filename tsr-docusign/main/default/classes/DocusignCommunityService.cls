public with sharing class DocusignCommunityService {

	// =========================================================
	//  PUBLIC METHODS
	//  WARNING - WARNING - WARNING - WARNING - WARNING - WARNING
	//
	// 		ONLY METHODS BELOW ARE ACCESSIBLE TO GUEST USERS
	//
	// https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_connectapi_public_communities.htm
	//
	// 		  TEST ALL METHODS AS GUEST USER IN COMMUNITY
	//
	// WARNING - WARNING - WARNING - WARNING - WARNING - WARNING
	// =========================================================

	public static ConnectApi.Community getCurrentRequestCommunity() {
		String ntwrkId = Network.getNetworkId();
		return ConnectApi.Communities.getCommunity(ntwrkId);
	}

	public static Boolean isCurrentRequestCommunity() {
		return Network.getNetworkId() != null;
	}

}