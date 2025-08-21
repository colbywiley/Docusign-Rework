@isTest(seeAllData=false)
private class DocusignOptionsTest {
	
	@isTest static void test_validate() {
		DocusignOptions docusignOptions = new DocusignOptions();
		System.assert(!docusignOptions.validate(), 'Should be false for the empty setting');
		insert DocusignTestDataFactory.createDocusignConfig();
		docusignOptions = new DocusignOptions();
		System.assert(docusignOptions.validate(), 'Should be true for the valid setting');
	}
	
}