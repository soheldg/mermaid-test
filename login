You got it! Since I cannot directly generate a downloadable file, I have provided the complete analysis and architectural blueprint in the requested **Markdown document format** below. You can easily copy the entire text and paste it into a file, saving it as a `.md` or `.txt` file, or paste it into a word processor (like Google Docs or Microsoft Word) to generate a downloadable `.docx` file.

***

# Project Blueprint: Login Revalidation Service Analysis 🔐

This document summarizes the comprehensive analysis of the **16 Java files** covering the application's layered validation and data access framework. It provides a blueprint for refactoring this system into a modern **Spring Boot** project, detailing the necessary services and data requirements for a successful login revalidation process (initiated by `loginctl.PersistData()` $\Rightarrow$ `RevalidateUser()`).

---

## I. Spring Boot Architectural Refactoring

The original system relies on a monolithic pattern where `Validator` classes perform business logic, validation, and direct database access (via `extends WebManager`). This is refactored into a **Controller-Service-Repository (CSR) architecture**.

| Original Monolith Component | Spring Boot Layer Equivalent | Responsibility in New Architecture |
| :--- | :--- | :--- |
| `loginctl.java` | **Controller** (`LoginController.java`) | Handles the client HTTP request, manages flow, and returns the response. |
| `*Validator.java`, `*Manager.java` | **Service** (`*Service.java`) | Executes core business logic, multi-step validation, and data transformation. |
| `WebManager` / `TranManager` | **Repository** (`*Repository.java`) | Replaced by **JPA** or **JdbcTemplate** for direct, encapsulated data access. |

---

## II. Services Required for Successful Revalidation

Successfully completing the entire login flow requires the orchestration of **10 distinct Service classes**. The revalidation is a cascade of checks executed sequentially by these services.

| Service Name | Original Files Consolidated | Key Responsibility |
| :--- | :--- | :--- |
| **`AuthService`** | `loginctl.java` | **Orchestrator:** Manages the entire sequential validation flow, calling all other services. |
| **`InfrastructureService`** | `WebManager`, `TranManager`, `QueryManager` | Manages connection pooling, transactions (**ACID**), and dynamic SQL execution. |
| **`UserService`** | `UserValidator.java` | **Identity Check:** Validates user ID existence, active status (`USERS`), and leave status (`USERLEAVEDTL`). |
| **`SecurityService`** | `Upwdinvalid.java` | **Policy Enforcement:** Manages password aging (`PASS_HIST`) and logs invalid attempts (`UPWDINV`, `USERLOCKLOG`). |
| **`AccessControlService`** | `AccessValidator.java` | **Device Check:** Validates workstation registration (`WSREGDTL`) and handles Biometric matching (`BIOFPIMG`). |
| **`BranchService`** | `BranchValidator`, `BcBranchValidator` | **Context Check:** Validates branch status (`MBRN`), operational time (`BRNBUSHRS`), and organizational hierarchy (`ADMINHIER`). |
| **`HierarchyService`** | `BranchlistValidator.java` | **Access Rules:** Enforces complex access rules, such as user's authorized branch groups/lists (`BRNLISTDTL`). |
| **`SessionService`** | `CommonValidator`, `eusrkillsessval` | **Session Management:** Checks for existing sessions (`SIGNINOUT`) and forces invalidation if needed (`USRSESSINFO`). |
| **`ConfigLoadService`** | `ReadInfo.java` | **Configuration Load:** Fetches menu structure (`SPMENU`), program access rights (`URPGMAR`), and UI field permissions (`SFDTLAVL`). |
| **`AuthorizationService`** | `efwdbopauthval`, `CMNaddValidator` | **Pending Work Check:** Retrieves records requiring authorization (`BOPAUTHQ`, `TBAAUTHQ`) and checks for pre-login alerts (`NOTEASSIGN`). |

---

## III. Information/Data Required for Success

A successful login revalidation requires passing a comprehensive set of data checks against the underlying database.

### A. Client Input Information (From HTTP Request)

These data fields must be provided in the initial login request for validation to proceed:

1.  **`USER_ID`**
2.  **`USER_PWD`** (Password)
3.  **`MBRN_CODE`** (Branch Code being accessed)
4.  **`MAC_ADDRESS` / `IP_ADDRESS`** (For workstation security)
5.  **`BIOMETRIC_DATA`** (If biometric login is enabled)

### B. Critical Database Checks (Must Pass Gates)

The `RevalidateUser()` process is a series of **"must pass" gates**. Failure at any step (e.g., user is inactive, branch is closed, MAC address is unauthorized) results in immediate failure.

| Validation Gate | Data Table(s) | Success Condition |
| :--- | :--- | :--- |
| **User Status & Roles** | `USERS`, `USERLEAVEDTL` | User ID is **Active** and not on leave. |
| **Password Policy** | `PASS_HIST`, `UPWDINV` | Password is **not expired** and the user is **not currently locked out**. |
| **Device Authorization** | `WSREGDTL`, `BIOFPIMG` | The connecting MAC/IP is **Registered** for the user/branch. |
| **Branch Validity** | `MBRN`, `BRNBUSHRS` | Branch must be **Active** and the current time must be **within business hours**. |
| **Session Conflict** | `SIGNINOUT`, `USRSESSINFO` | No existing **active session** is found, or the old session is successfully killed. |

#### Final Success Step:
The final action, **`loginctl.PersistData()`**, is the **INSERT** operation into the **`SIGNINOUT`** table, recording the successful login time and session ID, thereby establishing the new authorized session.

---

## IV. Mind Map Creation Summary

The journey from `loginctl` to full revalidation can be mapped hierarchically:

1.  **Central Node:** **`loginctl.java`** (The Orchestrator)
2.  **Primary Branches (Phases):**
    * **Foundation & Infrastructure**
    * **Identity & Security Validation**
    * **Context & Access Control**
    * **Session Management & Setup**
3.  **Secondary Nodes:** The **10 Spring Boot Services** listed above (e.g., `UserService`, `BranchService`).
4.  **Leaf Nodes:** The **Database Tables** that each service relies on (e.g., `USERS`, `MBRN`, `SIGNINOUT`).

The branches should connect sequentially, representing the flow: Infrastructure first, then Identity, then Context, and finally, Session Setup.
