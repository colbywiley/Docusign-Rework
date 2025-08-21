<aura:application controller="DocusignHandlerCtlr" access="global" extends="force:slds">

	<aura:handler name="init" value="{!this}" action="{!c.init}" />
	<aura:handler event="aura:waiting" action="{!c.showSpinner}" />
    <aura:handler event="aura:doneWaiting" action="{!c.hideSpinner}" />

    <aura:attribute name="initExecuted" type="Boolean" default="false" />
	<aura:attribute name="recordId" type="Id" />
	<aura:attribute name="parentRecordId" type="Id" />
	<aura:attribute name="flowType" type="String" />
	<aura:attribute name="event" type="String" />
	<aura:attribute name="errorMessage" type="String" />
	<aura:attribute name="emailResent" type="Boolean" default="false" />
	<aura:attribute name="emailSent" type="Boolean" default="false" />
	<aura:attribute name="pdfAttached" type="Boolean" default="false" />
	<aura:attribute name="docusignError" type="Boolean" default="false" />

	<div class="slds">

		<aura:if isTrue="{!v.emailSent}">
			<div class="slds-align--absolute-center">
				{!$Label.c.Docusign_Email_Sent}
			</div>
		</aura:if>

		<aura:if isTrue="{!v.emailResent}">
			<div class="slds-align--absolute-center">
                {!$Label.c.Docusign_Email_Resent}
			</div>
		</aura:if>

		<aura:if isTrue="{!v.pdfAttached}">
			<div class="slds-align--absolute-center">
				{!$Label.c.Docusign_Completion}
			</div>
		</aura:if>

		<aura:if isTrue="{!v.docusignError}">
			<div class="slds-align--absolute-center">
				{!v.errorMessage}
			</div>
		</aura:if>

		<lightning:spinner aura:id="tsr-spinner" variant="brand" size="large"/>
	</div>

</aura:application>