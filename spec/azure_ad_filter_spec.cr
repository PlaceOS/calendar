require "./spec_helper"

describe AzureADFilter, tags: ["azure_ad_filter"] do
  describe "#tokenize" do
    it "multiple conditional operators" do
      input = "startsWith(displayName,'user') or startsWith(givenName,'user') or startsWith(mail,'user')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 89},
        {:conditional_expression, 0, 89},
        {:function_expression, 0, 30},
        {:starts_with, 0, 10},
        {:identifier_path, 11, 22},
        {:identifier, 11, 22},
        {:value, 23, 29},
        {:or_operator, 31, 33},
        {:function_expression, 34, 62},
        {:starts_with, 34, 44},
        {:identifier_path, 45, 54},
        {:identifier, 45, 54},
        {:value, 55, 61},
        {:or_operator, 63, 65},
        {:function_expression, 66, 89},
        {:starts_with, 66, 76},
        {:identifier_path, 77, 81},
        {:identifier, 77, 81},
        {:value, 82, 88},
      ])
    end

    it "single function" do
      input = "endsWith(mail,'@hotmail.com')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 29},
        {:function_expression, 0, 29},
        {:ends_with, 0, 8},
        {:identifier_path, 9, 13},
        {:identifier, 9, 13},
        {:value, 14, 28},
      ])
    end

    it "single comparison operator" do
      input = "assignedLicenses/$count eq 0"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 28},
        {:comparison_expression, 0, 28},
        {:identifier_path, 0, 23},
        {:identifier, 0, 16},
        {:slash, 16, 17},
        {:identifier, 17, 23},
        {:eq_operator, 24, 26},
        {:value, 27, 28},
      ])
    end

    it "single 'in' operator" do
      input = "department in ('Retail', 'Sales')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 33},
        {:in_expression, 0, 33},
        {:identifier_path, 0, 10},
        {:identifier, 0, 10},
        {:in_operator, 11, 13},
        {:value_list, 14, 33},
        {:value, 15, 23},
        {:value, 25, 32},
      ])
    end

    it "single 'not' operator" do
      input = "not(companyName eq 'Test Corp')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 31},
        {:not_expression, 0, 31},
        {:not_operator, 0, 3},
        {:expression, 4, 30},
        {:comparison_expression, 4, 30},
        {:identifier_path, 4, 15},
        {:identifier, 4, 15},
        {:eq_operator, 16, 18},
        {:value, 19, 30},
      ])
    end

    it "single 'has' operator" do
      input = "scenarios has 'secureFoundation'"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 32},
        {:comparison_expression, 0, 32},
        {:identifier_path, 0, 9},
        {:identifier, 0, 9},
        {:has_operator, 10, 13},
        {:value, 14, 32},
      ])
    end

    it "single 'any' operator, multiple comparison operators" do
      input = "assignedPlans/any(a:a/servicePlanId eq 2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2 and a/capabilityStatus eq 'Suspended')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 114},
        {:lambda_expression, 0, 114},
        {:parent_identifier_path, 0, 14},
        {:identifier, 0, 13},
        {:slash, 13, 14},
        {:any_operator, 14, 17},
        {:expression, 18, 113},
        {:conditional_expression, 18, 113},
        {:comparison_expression, 18, 75},
        {:identifier_path, 18, 35},
        {:identifier, 18, 19},
        {:colon, 19, 20},
        {:identifier, 20, 21},
        {:slash, 21, 22},
        {:identifier, 22, 35},
        {:eq_operator, 36, 38},
        {:value, 39, 75},
        {:and_operator, 76, 79},
        {:comparison_expression, 80, 113},
        {:identifier_path, 80, 98},
        {:identifier, 80, 81},
        {:slash, 81, 82},
        {:identifier, 82, 98},
        {:eq_operator, 99, 101},
        {:value, 102, 113},
      ])
    end

    it "single lambda expression" do
      input = "assignedPlans/any(a:a/servicePlanId eq 2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2 and a/capabilityStatus eq 'Suspended')"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 114},
        {:lambda_expression, 0, 114},
        {:parent_identifier_path, 0, 14},
        {:identifier, 0, 13},
        {:slash, 13, 14},
        {:any_operator, 14, 17},
        {:expression, 18, 113},
        {:conditional_expression, 18, 113},
        {:comparison_expression, 18, 75},
        {:identifier_path, 18, 35},
        {:identifier, 18, 19},
        {:colon, 19, 20},
        {:identifier, 20, 21},
        {:slash, 21, 22},
        {:identifier, 22, 35},
        {:eq_operator, 36, 38},
        {:value, 39, 75},
        {:and_operator, 76, 79},
        {:comparison_expression, 80, 113},
        {:identifier_path, 80, 98},
        {:identifier, 80, 81},
        {:slash, 81, 82},
        {:identifier, 82, 98},
        {:eq_operator, 99, 101},
        {:value, 102, 113},
      ])
    end

    it "single lambda expression, single function" do
      input = "businessPhones/any(p:startsWith(p, '44'))"
      result = AzureADFilter::Parser.tokenize(input)
      result.should eq([
        {:expression, 0, 41},
        {:lambda_expression, 0, 41},
        {:parent_identifier_path, 0, 15},
        {:identifier, 0, 14},
        {:slash, 14, 15},
        {:any_operator, 15, 18},
        {:expression, 19, 40},
        {:function_expression, 19, 40},
        {:parent_identifier_path, 19, 21},
        {:identifier, 19, 20},
        {:colon, 20, 21},
        {:starts_with, 21, 31},
        {:identifier_path, 32, 33},
        {:identifier, 32, 33},
        {:value, 35, 39},
      ])
    end
  end

  # Filter examples from:
  # https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http#examples-using-the-filter-query-operator
  describe "#parse" do
    it "Get all users with the name Mary across multiple properties" do
      input = "startswith(displayName,'mary') or startswith(givenName,'mary') or startswith(surname,'mary') or startswith(mail,'mary') or startswith(userPrincipalName,'mary')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input.gsub(",", ", ").gsub("startswith", "startsWith"))
    end

    it "Get all users with mail domain equal to 'hotmail.com'" do
      input = "endsWith(mail,'@hotmail.com')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input.gsub(",", ", "))
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
      input = "isRead eq false"
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
      result.to_s.should eq(input.gsub("NOT", "not"))
    end

    it "List all users whose company name isn't undefined (that is, not a null value) or Microsoft" do
      input = "companyName ne null and NOT(companyName eq 'Microsoft')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input.gsub("NOT", "not"))
    end

    it "List all users whose company name is either undefined or Microsoft" do
      input = "companyName in (null, 'Microsoft')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input)
    end

    it "Use OData cast to get transitive membership in groups with a display name that starts with 'a' including a count of returned objects" do
      input = "startswith(displayName, 'a')"
      result = AzureADFilter::Parser.parse(input)
      result.to_s.should eq(input.gsub("startswith", "startsWith"))
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
        result.to_s.should eq(input.gsub(",", ", "))
      end

      it "not and endsWith" do
        input = "not(endsWith(mail,'OnMicrosoft.com'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input.gsub(",", ", "))
      end

      it "not and startsWith" do
        input = "not(startsWith(mail,'Pineview'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input.gsub(",", ", "))
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
        input = "not(appOwnerOrganizationId eq 72f988bf-86f1-41af-91ab-2d7cd011db47)"
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
        result.to_s.should eq(input.gsub(",", ", ").gsub("startswith", "startsWith"))
      end

      it "endsWith" do
        input = "proxyAddresses/any(p:endsWith(p,'OnMicrosoft.com'))"
        result = AzureADFilter::Parser.parse(input)
        result.to_s.should eq(input.gsub(",", ", "))
      end
    end
  end

  # Query examples from:
  # https://developers.google.com/admin-sdk/directory/v1/guides/search-users#examples
  describe "#to_google" do
    it "Search for a user by name" do
      input = "name eq 'Jane Smith'"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("name='Jane Smith'")
    end

    it "Search for users with a givenName OR familyName that contains a value" do
      input = "contains(name, 'Jane')"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("name:'Jane'")
    end

    it "Search for users matching an email prefix" do
      input = "startsWith(email, admin)"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("email:admin*")
    end

    it "Search for all super administrators" do
      input = "isAdmin eq true"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("isAdmin=true")
    end

    it "Search for users with orgTitles containing \"Manager\"" do
      input = "contains(orgTitle, Manager)"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("orgTitle:Manager")
    end

    it "Search for users with a common manager in their reporting chain" do
      input = "manager eq 'janesmith@example.com'"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("manager='janesmith@example.com'")
    end

    it "Search for users with the same direct manager" do
      input = "directManager eq 'bobjones@example.com'"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("directManager='bobjones@example.com'")
    end

    it "Search for users in a given country" do
      input = "addressCountry eq 'Sweden'"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("addressCountry='Sweden'")
    end

    it "Search for users in a specific organization" do
      input = "orgName eq 'Human Resources'"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("orgName='Human Resources'")
    end

    it "Search for managers in a specific organization" do
      input = "orgName eq Engineering and contains(orgTitle, Manager)"
      result = AzureADFilter::Parser.parse(input)
      result.to_google.should eq("orgName=Engineering orgTitle:Manager")
    end

    context "[Search custom user attributes]" do
      pending "Search for all employees that work on a specific project" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("EmploymentData.projects:'GeneGnomes'")
      end

      pending "Search for all employees in a specific location" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("EmploymentData.location='Atlanta'")
      end

      pending "Search for all employees above job level 7" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("EmploymentData.jobLevel>=7")
      end

      pending "Search for all employees with job levels that are >= 5 and < 8" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("EmploymentData.jobLevel:[5,8]")
      end

      pending "Search for all employees who are enrolled in 2-Step vVerification" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("isEnrolledIn2Sv=true")
      end

      pending "Search for all employees who have 2-Step Verification enforced" do
        input = ""
        result = AzureADFilter::Parser.parse(input)
        result.to_google.should eq("isEnforcedIn2Sv=true")
      end
    end
  end
end
