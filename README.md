# terraform-unifi-bootstrap
A bootstrapped configuration of UniFi allowing for immutable deployments.

## Notes

- All management and captive portal traffic is required to be proxied via CloudFlare as allowed in the security group.
- This code is designed to be deployed in an immutable way, e.g all updates / upgrades should be performed by redeploying the code and therefore completely rebuilding the infrastructure.

## Instructions
If you plan to use this code then you will need to first edit the ```_variables.tf``` file and copy your own SSH public key into the ```public.key``` file.

Additionally you will need to replace the following strings -

| String                                 | Description                                                                                                                |
|:--------------------------------------:|:--------------------------------------------------------------------------------------------------------------------------:|
| ```<your resource prefix here>```      | Your desired resource naming prefix. All resources are deployed in the format of ```PREFIX-ENV-REGION-UniFi-RESOURCETYPE```|
| ```<your administration CIDR here>```  | CIDR from which direct management traffic is allowed, this includes UniFi management ports and port 22 for SSH.            |

As with any code, I strongly recommend reading and understanding all files thoroughly before deploying.

## Further Reading
For more info on this project see the associated blog post at - https://mikehosker.net/bootstrapping-unifi-controller-on-aws