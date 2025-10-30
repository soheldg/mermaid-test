flowchart LR
  %% === Context ===
  classDef box fill:#0b1e39,stroke:#89a3ff,stroke-width:1,color:#e8f0ff
  classDef data fill:#0f2b4c,stroke:#7fd1b9,color:#eafffa
  classDef alert fill:#3a1b1b,stroke:#ff9b9b,color:#ffecec
  classDef edge stroke:#9fb3c8,color:#cfe3ff
  classDef ok fill:#113d2b,stroke:#8fd3b5,color:#eafff5

  subgraph User_WS[Developer Laptop / Admin WS]
    GIT[Git Repo<br/>(encrypted: <code>secrets.app.enc.yaml</code>)]:::data
    AGEKEY_LOCAL[(Offline backup<br/>age private key)]:::ok
  end

  subgraph AppHost[App Server (Bare-metal)]
    direction TB

    subgraph OS[Linux + systemd]
      INIT[/systemd boot/]:::box
      TMPFS[/tmpfs mount<br/><code>/run/valbot</code>/]:::ok
      KEYS[/age private key<br/><code>/etc/age/keys.txt</code> 0400/]:::ok
      SOPSDEC[sops decrypt<br/>(boot-time only)]:::box
      SHRED[shred on stop<br/>(secure delete)]:::alert
    end

    subgraph APP[Spring Boot App]
      SBJAR[java -jar<br/><code>validation-bot.jar</code>]:::box
      IMPORT[SPRING_CONFIG_IMPORT<br/><code>file:/run/valbot/app-secrets.yaml</code>]:::box
      CONF[(Decrypted config in RAM<br/><code>app-secrets.yaml</code>)]:::data
      LOGS[(Structured logs<br/><code>/var/log/valbot</code>)]:::data
    end
  end

  subgraph NET[Network]
    direction LR
    FWN[Firewall / ACL<br/>allow 1521 only]:::ok
  end

  subgraph DB[Oracle DB Server]
    ORA[(Oracle Listener 1521)]:::data
    VALSVC[(User: VALSVC<br/>Least-Privilege grants)]:::ok
  end

  %% === Edges ===
  GIT -- pull (encrypted) --> INIT:::edge
  INIT --> TMPFS:::edge
  INIT --> KEYS:::edge
  KEYS --> SOPSDEC:::edge
  GIT -- .enc.yaml --> SOPSDEC:::edge
  SOPSDEC -- decrypt --> CONF:::edge
  CONF --> IMPORT:::edge
  IMPORT --> SBJAR:::edge
  SBJAR -- JDBC (TLS recommended) --> FWN:::edge
  FWN --> ORA:::edge
  ORA --> VALSVC:::edge
  SBJAR --> LOGS:::edge
  SBJAR -. stop/shutdown .-> SHRED:::edge
  SHRED -. delete RAM file .-> CONF

  %% === Notes ===
  note right of KEYS
    age private key never in Git
    perms 0400, owner root
  end
  note right of CONF
    Decrypted secrets live only in RAM (tmpfs)
    No secrets on disk / YAML / env
  end
