require "./spec_helper"

describe AzureADFilter, focus: true do
  it "" do
    input = "accountEnabled eq true"
    # input = "startswith(displayName,'mary') or startswith(givenName,'mary') or startswith(surname,'mary') or startswith(mail,'mary') or startswith(userPrincipalName,'mary')"
    # input = "startsWith(displayName, 'mary')"
    result = AzureADFilter::Parser.parse(input)

    pp! result
    pp result.to_s
  end

  # it "parses equality filter expression" do
  #   input = "/users?$filter=userType eq 'Member'"
  #   result = AzureADFilter::Parser.parse(input)
  #   result.should eq({
  #     filter_type: "eq",
  #     property:    "userType",
  #     value:       "Member",
  #   })
  # end

  #   it "parses startsWith filter expression" do
  #     input = "/users?$filter=startsWith(displayName, 'john')"
  #     result = AzureADFilter::Parser.parse(input)
  #     result.should eq({
  #       filter_type: "startsWith",
  #       property:    "displayName",
  #       value:       "john",
  #     })
  #   end

  #   it "parses complex filter expression with and/or operators" do
  #     input = "/users?$filter=startsWith(displayName, 'mary') or startsWith(givenName, 'mary')"
  #     result = AzureADFilter::Parser.parse(input)
  #     result.should eq({
  #       filter_type: "or",
  #       left:        {
  #         filter_type: "startsWith",
  #         property:    "displayName",
  #         value:       "mary",
  #       },
  #       right: {
  #         filter_type: "startsWith",
  #         property:    "givenName",
  #         value:       "mary",
  #       },
  #     })
  #   end

  #   it "parses filter expression with lambda operators" do
  #     input = "/users?$filter=assignedLicenses/any(s:s/skuId eq 184efa21-98c3-4e5d-95ab-d07053a96e67)"
  #     result = AzureADFilter::Parser.parse(input)
  #     result.should eq({
  #       filter_type:     "any",
  #       collection:      "assignedLicenses",
  #       lambda_variable: "s",
  #       expression:      {
  #         filter_type: "eq",
  #         property:    "skuId",
  #         value:       "184efa21-98c3-4e5d-95ab-d07053a96e67",
  #       },
  #     })
  #   end
end
