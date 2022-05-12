# conftest-terraform-workflow
Experiments with conftest, terraform workflow


`terratest`, is it possible to create an IAM Role that is ONLY able to create resources if they are tagged?

https://docs.aws.amazon.com/IAM/latest/UserGuide/access_iam-tags


aws:RequestTag: To indicate that a particular tag key or tag key and value must be present in a request. Other tags can also be specified in the request.

Use with the StringEquals condition operator to enforce a specific tag key and value combination, for example, to enforce the tag cost-center=cc123:

"StringEquals": { "aws:RequestTag/cost-center": "cc123" }