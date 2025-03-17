# Lastbalansering och automatisk skalning

Detta är en praktisk övning som visar hur lastbalansering samt vertikal skalning fungerar.

## Förberedelser

1. Klona repo och navigera till projektmappen:
   ```bash
   git clone https://github.com/khdev-devops/infra-mar18-1-load-and-scale
   ```
   ```bash
   cd infra-mar18-1-load-and-scale
   ```

2. Installera OpenTofu i AWS CloudShell
   ```bash
   ./install_tofu.sh
   ```

3. Skapa nycklar för att användas vid anslutaning till EC2 med SSH (om du inte redan har en tofu-key):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/tofu-key -N ""
   ```

4. Skapa din egen `terraform.tfvars`
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   - Editera `terraform.tfvars` och sätt CloudShell-IP (`curl ifconfig.me`) så vi kan nå EC-instanser med SSH från CloudShell.

5. Initiera OpenTofu:
   ```sh
   tofu init
   tofu plan
   tofu apply
   ```

---

## Del 1: Lastbalansering med två manuella instanser

Vi skapar en lastbalanserare som balanserar trafik mellan de två redan skapade EC2-instanserna (då du gjorde `tofu apply`).

### 1. Skapa en Application Load Balancer (ALB)
1. Gå till **AWS Console > EC2 > Load Balancers**.
2. Klicka på **Create Load Balancer**.
3. Välj **Application Load Balancer**.
4. Namn: `mar18-alb`.
5. Scheme: **Internet-facing**.
6. IP type: **IPv4**.
7. Välj **de två publika subnäten**.
8. Klicka **Next**.

### 2. Skapa en Target Group
1. Gå till **AWS Console > EC2 > Target Groups**.
2. Klicka **Create Target Group**.
3. Namn: `mar18-target-group`.
4. Protocol: **HTTP**.
5. Port: **80**.
6. Target Type: **Instance**.
7. Välj **default VPC** och klicka **Next**.
8. Lägg till de två manuella EC2-instanserna som targets och klicka **Create**.

### 3. Koppla ALB till Target Group
1. Gå tillbaka till **Load Balancer > Listeners**.
2. Klicka på **View/Edit Rules**.
3. Lägg till en regel som skickar trafik till `mar18-target-group`.

### 4. Testa lastbalanseringen
1. Gå till **EC2 > Load Balancers**.
2. Kopiera **DNS-namnet** för `mar18-alb`.
3. Öppna en webbläsare och besök:
   ```
   http://<ALB-DNS-namnet>
   ```
4. Ladda om sidan flera gånger för att se att trafiken skickas till båda instanserna.

### 5. Stoppa de två manuella instanserna
1. Gå till **EC2 > Instances**.
2. Markera `mar18-opentofu-webserver-1` och `mar18-opentofu-webserver-2`.
3. Klicka **Instance State > Stop**.

---

## Del 2: Lastbalansering med Auto Scaling Group (ASG)

Vi skapar en skalningsgrupp som automatiskt startar (och stoppar EC-instanser) för att kunna serva trafiken. 
Detta är viktigt när trafik varierar över tid. Detta är ett exempel på vertikal skalning.

### 1. Ta bort de manuella instanserna från Target Group
1. Gå till **EC2 > Target Groups**.
2. Klicka på `mar18-target-group`.
3. Gå till **Targets** och ta bort de två instanserna.

### 2. Skapa en Auto Scaling Group (ASG)
1. Gå till **EC2 > Auto Scaling Groups**.
2. Klicka **Create Auto Scaling Group**.
3. Namn: `mar18-asg`.
4. Välj **Launch Template**: `mar18-web-lt`.
5. Välj **de två publika subnäten**.
6. Klicka **Next** och **Skip to Review**.
7. Klicka **Create Auto Scaling Group**.

### 3. Koppla ASG till Target Group
1. Gå till **EC2 > Auto Scaling Groups**.
2. Klicka på `mar18-asg`.
3. Gå till **Load Balancing** och välj `mar18-target-group`.

### 4. Testa Auto Scaling genom att generera last
1. SSH till en av de nyskapade instanserna:
   ```sh
   ssh -i ~/.ssh/tofu-key ec2-user@<asg-instance-ip>
   ```
2. Installera `stress-ng` och starta den (detta gör att instansen kommer vara mycket upptagen och CPU-nivån går upp):
   ```sh
   sudo dnf install -y stress-ng
   stress-ng --cpu 2 --timeout 300s
   ```
3. Övervaka Auto Scaling Group och/eller instanser i listan av EC2-instanser.
4. Se om nya instanser skapas när CPU-belastningen ökar.

### 5. Viktigt! Rensa upp resurser

1. Radera ASG:
   - Gå till **EC2 > Auto Scaling Groups**.
   - Markera `mar18-asg` och klicka **Delete**.

2. Radera ALB:
   - Gå till **EC2 > Load Balancers**.
   - Markera `mar18-alb` och klicka **Delete**.

3. Radera Target Group:
   - Gå till **EC2 > Target Groups**.
   - Markera `mar18-target-group` och klicka **Delete**.

4. Ta bort resurserna som OpenTofu skapade:
   ```sh
   tofu destroy
   ```
