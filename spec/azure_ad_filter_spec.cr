require "./spec_helper"

describe AzureADFilter, focus: true do
  # it "" do
  #   input = "accountEnabled eq true"
  #   # input = "startswith(displayName,'mary') or startswith(givenName,'mary') or startswith(surname,'mary') or startswith(mail,'mary') or startswith(userPrincipalName,'mary')"
  #   # input = "startsWith(displayName, 'mary')"
  #   result = AzureADFilter::Parser.parse(input)

  #   pp! result
  #   pp result.to_s
  # end

  # Filter examples from:
  # https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http#examples-using-the-filter-query-operator
  describe "filter examples" do
    it "Get all users with the name Mary across multiple properties" do
      input = "startswith(displayName,'mary') or startswith(givenName,'mary') or startswith(surname,'mary') or startswith(mail,'mary') or startswith(userPrincipalName,'mary')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all users with mail domain equal to 'hotmail.com'" do
      input = "endsWith(mail,'@hotmail.com')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all users without assigned licenses" do
      input = "assignedLicenses/$count eq 0"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all the signed-in user's events that start after 7/1/2017" do
      input = "start/dateTime ge '2017-07-01T08:00'"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all emails from a specific address received by the signed-in user" do
      input = "from/emailAddress/address eq 'someuser@example.com'"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all emails received by the signed-in user in April 2017" do
      input = "ReceivedDateTime ge 2017-04-01 and receivedDateTime lt 2017-05-01"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all unread mail in the signed-in user's Inbox" do
      input = "filter=isRead eq false"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Get all users in the Retail and Sales departments" do
      input = "department in ('Retail', 'Sales')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "List users with a particular service plan that is in a suspended state" do
      input = "assignedPlans/any(a:a/servicePlanId eq 2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2 and a/capabilityStatus eq 'Suspended')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "List all non-Microsoft 365 groups in an organization" do
      input = "NOT groupTypes/any(c:c eq 'Unified')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "List all users whose company name isn't undefined (that is, not a null value) or Microsoft" do
      input = "companyName ne null and NOT(companyName eq 'Microsoft')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "List all users whose company name is either undefined or Microsoft" do
      input = "companyName in (null, 'Microsoft')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Use OData cast to get transitive membership in groups with a display name that starts with 'a' including a count of returned objects" do
      input = "startswith(displayName, 'a')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    # For single primitive types like String, Int, and dates
    context "[single primitive types]" do
      it "eq" do
        input = "userType eq 'Member'"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not" do
        input = "not(userType eq 'Member')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "ne" do
        input = "companyName ne null"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "startsWith" do
        input = "startsWith(userPrincipalName, 'admin')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "endsWith" do
        input = "endsWith(mail, '@outlook.com')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "in" do
        input = "userType in ('Guest')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "le" do
        input = "registrationDateTime le 2021-01-02T12:00:00Z"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "ge" do
        input = "registrationDateTime ge 2021-01-02T12:00:00Z"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and endsWith" do
        input = "not(endsWith(mail, 'OnMicrosoft.com'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and startsWith" do
        input = "not(startsWith(mail, 'A'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and eq" do
        input = "not(companyName eq 'Contoso E.A.')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and in" do
        input = "not(userType in ('Member'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "contains" do
        input = "contains(scope/microsoft.graph.accessReviewQueryScope/query, './members')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "has" do
        input = "scenarios has 'secureFoundation'"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end
    end

    # For a collection of primitive types
    context "[collection of primitive types]" do
      it "eq" do
        input = "groupTypes/any(c:c eq 'Unified')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not" do
        input = "not(groupTypes/any(c:c eq 'Unified'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "ne" do
        input = "companyName ne null"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "startsWith" do
        input = "businessPhones/any(p:startsWith(p, '44'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "endsWith" do
        input = "endsWith(mail,'@outlook.com')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and endsWith" do
        input = "not(endsWith(mail,'OnMicrosoft.com'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and startsWith" do
        input = "not(startsWith(mail,'Pineview'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and eq" do
        input = "not(mail eq 'PineviewSchoolStaff@Contoso.com')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "eq and $count for empty collections" do
        input = "assignedLicenses/$count eq 0"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "ne and $count for empty collections" do
        input = "assignedLicenses/$count ne 0"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and $count for empty collections" do
        input = "not(assignedLicenses/$count eq 0)"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "$count for collections with one object" do
        input = "owners/$count eq 1"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end
    end

    # For GUID types
    context "[GUID types]" do
      it "eq" do
        input = "appOwnerOrganizationId eq 72f988bf-86f1-41af-91ab-2d7cd011db47"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not" do
        input = "not(appOwnerOrganizationId eq 72f988bf-86f1-41af-91ab-2d7cd011db47)&$count=true"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end
    end

    # For a collection of GUID types
    context "[collection of GUID types]" do
      it "eq" do
        input = "alternativeSecurityIds/any(a:a/type eq 2)"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "le" do
        input = "alternativeSecurityIds/any(a:a/type le 2)"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "ge" do
        input = "alternativeSecurityIds/any(a:a/type ge 2)"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end
    end

    # For a collection of complex types
    context "[collection of complex types]" do
      it "eq" do
        input = "authorizationInfo/certificateUserIds/any(x:x eq '9876543210@mil')"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "not and eq" do
        input = "not(authorizationInfo/certificateUserIds/any(x:x eq '9876543210@mil'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "startsWith" do
        input = "authorizationInfo/certificateUserIds/any(x:startswith(x,'987654321'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end

      it "endsWith" do
        input = "proxyAddresses/any(p:endsWith(p,'OnMicrosoft.com'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input)
      end
    end
  end
end
