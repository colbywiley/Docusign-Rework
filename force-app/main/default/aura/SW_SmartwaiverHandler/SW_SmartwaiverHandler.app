<aura:application controller="DocusignHandlerCtlr" access="global" extends="force:slds">

    <aura:handler name="init" value="{!this}" action="{!c.init}" />
    <aura:handler event="aura:waiting" action="{!c.showSpinner}" />
    <aura:handler event="aura:doneWaiting" action="{!c.hideSpinner}" />

    <!-- Core state -->
    <aura:attribute name="initExecuted" type="Boolean" default="false" />
    <aura:attribute name="recordId" type="Id" />
    <aura:attribute name="parentRecordId" type="Id" />
    <aura:attribute name="flowType" type="String" />
    <aura:attribute name="event" type="String" />
    <aura:attribute name="waiverId" type="String" />
    <aura:attribute name="errorMessage" type="String" />
    <aura:attribute name="emailResent" type="Boolean" default="false" />
    <aura:attribute name="emailSent" type="Boolean" default="false" />
    <aura:attribute name="pdfAttached" type="Boolean" default="false" />
    <aura:attribute name="docusignError" type="Boolean" default="false" />

    <!-- Polling config -->
    <aura:attribute name="retryDelay" type="Integer" default="2000" /> <!-- ms -->
    <aura:attribute name="retryCount" type="Integer" default="0" />
    <aura:attribute name="maxRetries" type="Integer" default="0" />     <!-- 0 = infinite -->
    <aura:attribute name="statusMessage" type="String" default="" />

    <div class="slds slds-p-around_medium">

        <!-- Live status while finalizing Smartwaiver -->
        <aura:if isTrue="{!not(empty(v.statusMessage))}">
            <div class="slds-text-align_center slds-text-title_bold slds-m-bottom_small">
                {!v.statusMessage}
            </div>
        </aura:if>

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