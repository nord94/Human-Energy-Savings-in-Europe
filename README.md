# 🌍 Human Energy Savings in Europe

[![Data Collection](https://img.shields.io/badge/Stage-Data%20Collection-blue)]()
[![Modeling](https://img.shields.io/badge/Stage-Modeling-yellow)]()
[![Visualization](https://img.shields.io/badge/Stage-Visualization-brightgreen)]()
[![Status](https://img.shields.io/badge/Status-In%20Progress-lightgrey)]()

> _Turning sweat into watts!_ 🚴⚡
## 💡 Project Idea

- The **World Health Organization (WHO)** recommends that adults perform at least **150 minutes of moderate-intensity activity per week**.
- Many **modern gym machines** (e.g., bikes, ellipticals) can **harvest energy** from workouts.
- By combining **population data** and **machine efficiency**, we estimate the **potential energy output** for each country.

🔋 **Imagine** millions of people exercising — and **generating clean energy** at the same time!

This project contains an Airflow setup to analyze energy savings data across Europe.

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

---
## 🔧 Tech Stack

Our project is built on a modern data engineering stack:

### Core Technologies
- **Apache Airflow**: Workflow orchestration platform for scheduling and monitoring data pipelines
- **PostgreSQL**: Relational database used for both Airflow metadata and our Data Warehouse
- **dbt (data build tool)**: SQL-based transformation tool following software engineering best practices
- **Docker**: Containerization for consistent development and deployment environments
- **Python**: Primary programming language for DAGs, data processing, and utilities

### Infrastructure
- **Docker Compose**: Local development environment with multiple services
- **Terraform**: Infrastructure as Code (IaC) for AWS deployment
- **AWS ECS**: Container orchestration for production workloads
- **AWS ECR**: Repository for Docker images

### Data Processing
- **Pandas**: Data manipulation and analysis library
- **SQLAlchemy**: SQL toolkit and Object-Relational Mapping
- **psycopg2**: PostgreSQL adapter for Python

### Testing & Quality
- **dbt test**: Data quality validation framework
- **Pytest**: Python testing framework (for DAG validation)
- **Custom Validators**: Domain-specific validation tests

This architecture allows for scalable, maintainable, and testable data pipelines with clear separation of concerns between extraction, transformation, and analysis layers.

## 🔄 Data Pipeline

The project includes automated data pipelines for extracting, transforming, and loading data related to Europe's energy usage:

### Data Sources

1. **Eurostat Population Data**: Demographics data for European countries, extracted daily
2. **WRI Power Plant Database**: Data about power plants across Europe, extracted weekly

### Data Warehouse (DWH)

The setup includes a dedicated PostgreSQL database serving as a Data Warehouse with:

- Schema for energy consumption data
- Tables for population statistics
- European power plant information

### Airflow DAGs

DAGs (Directed Acyclic Graphs) handle the ETL processes:

- `dwh_connection_check`: Verifies connectivity to the DWH database
- `extract_eurostat_data`: Extracts and loads population statistics from Eurostat
- `extract_wri_data`: Extracts and loads European power plant data from WRI
- `transform_data`: Transforms raw data using dbt to create analytical models
- `example_dag`: Sample DAG for testing the Airflow setup

All DAGs follow a pattern of checking database connectivity before performing their operations, with proper error handling and logging.

### Data Transformation with dbt

We use [dbt (data build tool)](https://www.getdbt.com/) to transform the raw data loaded into our data warehouse:

- **Modular transformations**: Well-organized SQL transformations in the dbt project
- **Testing and validation**: Automated tests ensure data quality, including custom tests to validate European countries
- **Documentation**: Self-documenting models with comprehensive descriptions

Key models include:

- `energy_comparison`: Combines power plant data with population statistics to compare conventional energy sources with theoretical human power generation

The transformation layer follows software engineering best practices:

- **Version control**: All transformations are versioned and tested
- **Data validation**: Automated tests run after transformations to ensure data quality
- **Environment-based deployment**: Separate dev/prod environments controlled by profiles

This workflow ensures data consistency, reliability, and traceability throughout the entire process.

## Project Structure

```
├── dags/                  # Airflow DAGs
│   ├── dwh_connection_check.py     # DAG to verify DWH connection
│   ├── example_dag.py              # Example DAG for testing
│   ├── extract_eurostat_data.py    # DAG to extract population data from Eurostat
│   ├── extract_wri_data.py         # DAG to extract European power plant data from WRI
│   └── transform_data.py           # DAG to transform data using dbt
├── dbt/                   # dbt project for data transformation
│   ├── human_energy_project/       # dbt project directory
│   │   ├── models/                 # dbt models
│   │   │   ├── schema.yml          # Schema definitions and tests
│   │   │   ├── marts/              # Marts models for reporting
│   │   │   └── staging/            # Staging models
│   │   ├── macros/                 # Custom macros including data tests
│   │   └── dbt_project.yml         # dbt project configuration
│   ├── profiles.yml                # dbt connection profiles
│   └── run_dbt.sh                  # Script to run dbt commands
├── docker/                # Docker configuration files
│   ├── airflow/           # Airflow Docker configuration
│   │   ├── Dockerfile     # Airflow Dockerfile
│   │   └── entrypoint.sh  # Custom entrypoint script for Airflow
│   └── postgres/          # PostgreSQL Docker configuration
│       ├── Dockerfile             # PostgreSQL Dockerfile
│       ├── entrypoint-wrapper.sh  # Custom entrypoint script for PostgreSQL
│       └── init-scripts/          # PostgreSQL initialization scripts
│           ├── 01-init.sql        # Airflow database init script
│           └── 02-init-dwh.sql    # Data Warehouse init script
├── logs/                  # Airflow logs directory
├── plugins/               # Airflow plugins directory
├── scripts/               # Utility scripts
├── terraform/             # Terraform configuration
│   ├── main.tf            # Main Terraform configuration
│   ├── outputs.tf         # Terraform outputs
│   └── variables.tf       # Terraform variables
├── docker-compose.yml     # Docker Compose configuration for local development
├── docker-compose-build.yml # Docker Compose configuration for building images
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

### 💾 Local Database Access

When running the project locally, you can connect to the databases using the following details:

#### Airflow Metadata Database
- **Host**: localhost
- **Port**: 5432
- **Database**: airflow
- **Username**: airflow
- **Password**: airflow

#### Data Warehouse (DWH)
- **Host**: localhost
- **Port**: 5433
- **Database**: energy_dwh
- **Username**: dwh_user
- **Password**: dwh_password

These can be accessed using any PostgreSQL client such as:
- [pgAdmin](https://www.pgadmin.org/)
- [DBeaver](https://dbeaver.io/)
- [DataGrip](https://www.jetbrains.com/datagrip/)

You can also connect programmatically using Python:

```python
import psycopg2

# Connect to the DWH
conn = psycopg2.connect(
    host="localhost",
    port=5433,
    database="energy_dwh",
    user="dwh_user",
    password="dwh_password"
)

# Execute a query
cursor = conn.cursor()
cursor.execute("SELECT * FROM energy_comparison LIMIT 10")
results = cursor.fetchall()

# Print results
for row in results:
    print(row)

# Close connection
cursor.close()
conn.close()
```

---

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
   docker-compose -f docker-compose-build.yml build
   aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com
   docker tag human-energy-airflow:latest <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com/human-energy-airflow:latest
   docker push <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com/human-energy-airflow:latest
   ```

4. Access the deployed Airflow instance:
   ```
   cd terraform
   echo "Airflow URL: http://$(terraform output -raw airflow_load_balancer_dns)"
   ```

---

## 🔮 Next Steps

- Expand dbt models to cover more complex energy comparisons
- Create analyses comparing energy output by country and demographic attributes
- Add more data quality tests to ensure robust transformations
- Fine-tune energy generation assumptions (taking machine type and intensity into account)
- Adjust calculations by **age group** and **exercise compliance rates**
- Create **country-level dashboards** and visual comparisons
- Explore **scenarios** for increased participation or improved machine efficiency

---

## 🤝 Contributions

Ideas, corrections, and improvements are **very welcome**! Feel free to open an issue or a pull request.

## License

See the [LICENSE](LICENSE) file for details.

---

# 🚴‍♂️💨 Let's pedal toward a greener future!
