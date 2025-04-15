# AWS-K8s-Setup

This creates AWS Kubernetes setup with 1 Master and 2 Worker nodes.

**Steps**
import this to terraform and run 

    terraform init

    terraform plan

    terraform apply -auto-approve

Once completed, run this command in Master node

    kubectl get nodes 
    
**To Destroy**
    
    terraform destroy 
**Note**

If you are using vscode, change the script EOF sequence from CRLF to LF to both shell scripts
![image](https://github.com/user-attachments/assets/7ae6cf8a-b978-4d51-9f16-59ef65bd5a00)

It will ask you for selection at the top
![image](https://github.com/user-attachments/assets/b12551a9-0ffd-4c03-8fe3-bab7ff9186a9)
