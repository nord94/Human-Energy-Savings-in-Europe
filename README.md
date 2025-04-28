# 🌍 Human Energy Savings in Europe

[![Data Collection](https://img.shields.io/badge/Stage-Data%20Collection-blue)]()
[![Modeling](https://img.shields.io/badge/Stage-Modeling-yellow)]()
[![Visualization](https://img.shields.io/badge/Stage-Visualization-brightgreen)]()
[![Status](https://img.shields.io/badge/Status-In%20Progress-lightgrey)]()

> _Turning sweat into watts!_ 🚴⚡

This project contains an Airflow setup to analyze energy savings data across Europe.

## Project Structure

```
├── dags/                  # Airflow DAGs
│   └── example_dag.py     # Example DAG
├── docker/                # Docker configuration files
│   ├── airflow/           # Airflow Docker configuration
│   │   └── Dockerfile     # Airflow Dockerfile
│   └── postgres/          # PostgreSQL Docker configuration
│       ├── Dockerfile     # PostgreSQL Dockerfile
│       └── init-scripts/  # PostgreSQL initialization scripts
├── logs/                  # Airflow logs directory
├── plugins/               # Airflow plugins directory
├── scripts/               # Utility scripts
│   └── build_and_push.sh  # Script to build and push Docker images to ECR
├── terraform/             # Terraform configuration
│   ├── main.tf            # Main Terraform configuration
│   ├── outputs.tf         # Terraform outputs
│   └── variables.tf       # Terraform variables
├── docker-compose.yml     # Docker Compose configuration for local development
├── LICENSE                # Project license
└── README.md              # This file
```

## Local Development

### Prerequisites

- Docker and Docker Compose
- AWS CLI
- Terraform

### Running locally

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/Human-Energy-Savings-in-Europe.git
   cd Human-Energy-Savings-in-Europe
   ```

2. Start the containers:
   ```
   docker-compose up -d
   ```

3. Access Airflow at [http://localhost:8080](http://localhost:8080) with the following credentials:
   - Username: admin
   - Password: admin

## AWS Deployment

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform
- Docker

### Deployment Steps

1. Initialize Terraform:
   ```
   cd terraform
   terraform init
   ```

2. Apply the Terraform configuration:
   ```
   terraform apply
   ```

3. Build and push the Docker images to ECR:
   ```
   cd ../scripts
   chmod +x build_and_push.sh
   ./build_and_push.sh
   ```

4. Access the deployed Airflow instance:
   ```
   cd ../terraform
   echo "Airflow URL: http://$(terraform output -raw airflow_load_balancer_dns)"
   ```

## Security Considerations

- For production use, replace the default passwords with secure ones
- Consider adding SSL/TLS encryption for the load balancer
- Store sensitive information like database passwords in AWS Secrets Manager

## License

See the [LICENSE](LICENSE) file for details.

## 💡 Project Idea

- The **World Health Organization (WHO)** recommends that adults perform at least **150 minutes of moderate-intensity activity per week**.
- Many **modern gym machines** (e.g., bikes, ellipticals) can **harvest energy** from workouts.
- By combining **population data** and **machine efficiency**, we estimate the **potential energy output** for each country.

🔋 **Imagine** millions of people exercising — and **generating clean energy** at the same time!

---

## 📚 Data Sources

| Topic | Source |
|:-----|:------|
| WHO Physical Activity Guidelines | [View Guidelines](https://www.who.int/initiatives/behealthy/physical-activity#:~:text=18%E2%80%9364%20years-,Should%20do%20at%20least%20150%20minutes%20of%20moderate%2Dintensity%20physical%20activity%20throughout%20the%20week) |
| Total Population in Europe | [Eurostat Data](https://ec.europa.eu/eurostat/databrowser/view/tps00001/default/table?lang=en&category=t_demo.t_demo_pop) |
| Population by Age Groups | [Eurostat Age Data](https://ec.europa.eu/eurostat/databrowser/view/tps00010/default/table?lang=en&category=t_demo.t_demo_ind) |
| Energy Output from Workout Machines | [GoSportsArt - Eco-Powr FAQ](https://www.gosportsart.com/eco-powr-questions-answers/#:~:text=An%20average%201%2Dhour%20workout%20can%20produce%20approximately%20160%20watt%2Dhours%20of%20electricity) |

---

## 🔢 Assumptions

- 🏋️ **Average energy generation** per 1-hour workout: **~160 Wh**.
- 📅 **Weekly exercise time**: 150 minutes (~2.5 hours) per person.
- ⚡️ **Energy-producing machines** assumed to operate at typical efficiency levels.

---

## 📈 Current Status

- ✅ Data sources identified and connected.
- ✅ Initial 2024 estimates calculated!
- 📊 Visualizations coming soon.

> _First approximate results for 2024:_  
> _*(Insert an image/graph here)*_

---

## 🔮 Next Steps

- Fine-tune energy generation assumptions (taking machine type and intensity into account).
- Adjust calculations by **age group** and **exercise compliance rates**.
- Create **country-level dashboards** and visual comparisons.
- Explore **scenarios** for increased participation or improved machine efficiency.

---

## 🤝 Contributions

Ideas, corrections, and improvements are **very welcome**! Feel free to open an issue or a pull request.

---

# 🚴‍♂️💨 Let's pedal toward a greener future!
