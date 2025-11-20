# NSUPDATE Functional Reference

## Overview

`nsupdate` is a Dynamic DNS Update utility that submits update requests as defined in RFC 2136 to a name server. It allows resource records to be added or removed from a zone without manually editing zone files. Updates are sent to the zone's master server (identified by the MNAME field of the zone's SOA record).

## Core Functional Components

### 1. Session Configuration Commands

These commands establish the context for all subsequent operations within a session.

#### `server <servername> [port]`
Specifies the target name server for all dynamic update requests in the session.
- **Default behavior**: If not specified, nsupdate sends updates to the master server identified by the zone's SOA MNAME field
- **port**: Optional port number (default: 53)

#### `local <address> [port]`
Specifies the local address/port to use when sending update requests.
- **Default behavior**: If not specified, the system chooses the address and port
- **port**: Optional local port number

#### `zone <zonename>`
Specifies the zone to which all updates in the session will be made.
- **Default behavior**: If not specified, nsupdate attempts to determine the correct zone from the resource record names

#### `class <classname>`
Sets the default class for all resource records in the session.
- **Default**: IN (Internet)
- **Effect**: All subsequent commands use this class unless explicitly overridden

### 2. Prerequisite Commands

Prerequisites establish conditions that must be met for the update request to succeed. All prerequisites in a session are evaluated atomically before any updates are applied.

#### `prereq nxdomain <domain-name>`
**Condition**: The domain name must NOT exist (no resource records of any type).

#### `prereq yxdomain <domain-name>`
**Condition**: The domain name must exist (at least one resource record of any type).

#### `prereq nxrrset <domain-name> [class] <type>`
**Condition**: No resource record of the specified type must exist for the domain name.

#### `prereq yxrrset <domain-name> [class] <type>`
**Condition**: At least one resource record of the specified type must exist for the domain name.

#### `prereq yxrrset <domain-name> [class] <type> <data...>`
**Condition**: Resource records of the specified type must exist with data that exactly matches the specified data.

### 3. Update Commands

Update commands specify the actual modifications to be made to the zone.

#### `update add <domain-name> <ttl> [class] <type> <data...>`
Adds a new resource record with the specified parameters.

#### `update delete <domain-name> [class] [type [data...]]`
Deletes resource records based on the specificity of the command:
- **No type specified**: Deletes all records for the domain name
- **Type specified**: Deletes all records of that type for the domain name
- **Type and data specified**: Deletes only records matching both type and data

### 4. Session Control Commands

#### `send` (or blank line)
Submits the accumulated prerequisites and updates as a single atomic Dynamic DNS update request to the name server. The session is then reset for the next batch of commands.

#### `show`
Displays the current message containing all prerequisites and updates accumulated since the last send.

#### `answer`
Displays the answer/response from the last update request.

---

## Use-Cases and Examples

All use-cases are presented as complete sessions showing input commands and resulting zone file changes.

### Use-Case 1: Unconditional Addition of New Records

**Goal**: Add new resource records to the zone without any preconditions.

**Session Input**:
```
server ns1.example.com
zone example.com
update add host1.example.com 3600 A 192.168.1.10
update add host2.example.com 7200 A 192.168.1.20
send
```

**Zone File Before**:
```
example.com.    IN  SOA ns1.example.com. admin.example.com. (...)
```

**Zone File After**:
```
example.com.    IN  SOA ns1.example.com. admin.example.com. (...)
host1.example.com.  3600  IN  A    192.168.1.10
host2.example.com.  7200  IN  A    192.168.1.20
```

---

### Use-Case 2: Unconditional Deletion of Records

**Goal**: Remove resource records from the zone without preconditions.

**Scenario 2a: Delete all records for a name**

**Session Input**:
```
zone example.com
update delete oldhost.example.com
send
```

**Zone File Before**:
```
oldhost.example.com.  3600  IN  A     192.168.1.50
oldhost.example.com.  3600  IN  AAAA  2001:db8::1
oldhost.example.com.  3600  IN  TXT   "old server"
```

**Zone File After**:
```
; All records for oldhost.example.com are removed
```

**Scenario 2b: Delete records of a specific type**

**Session Input**:
```
zone example.com
update delete host.example.com A
send
```

**Zone File Before**:
```
host.example.com.  3600  IN  A     192.168.1.100
host.example.com.  3600  IN  AAAA  2001:db8::10
```

**Zone File After**:
```
host.example.com.  3600  IN  AAAA  2001:db8::10
```

**Scenario 2c: Delete specific record with matching data**

**Session Input**:
```
zone example.com
update delete host.example.com A 192.168.1.100
send
```

**Zone File Before**:
```
host.example.com.  3600  IN  A  192.168.1.100
host.example.com.  3600  IN  A  192.168.1.101
```

**Zone File After**:
```
host.example.com.  3600  IN  A  192.168.1.101
```

---

### Use-Case 3: Atomic Record Replacement

**Goal**: Replace existing records with new ones in a single atomic transaction.

**Session Input**:
```
zone example.com
update delete host.example.com A
update add host.example.com 3600 A 10.0.0.50
send
```

**Zone File Before**:
```
host.example.com.  7200  IN  A  192.168.1.200
```

**Zone File After**:
```
host.example.com.  3600  IN  A  10.0.0.50
```

---

### Use-Case 4: Conditional Addition (Safe Insert)

**Goal**: Add a record only if it doesn't already exist, preventing duplicates or conflicts.

**Scenario 4a: Add only if domain name doesn't exist**

**Session Input**:
```
zone example.com
prereq nxdomain newhost.example.com
update add newhost.example.com 86400 A 172.16.1.1
send
```

**Zone File Before**:
```
; newhost.example.com does not exist
```

**Zone File After** (prerequisite met):
```
newhost.example.com.  86400  IN  A  172.16.1.1
```

**Zone File After** (prerequisite NOT met - if newhost.example.com existed):
```
; No changes - update rejected
```

**Scenario 4b: Add only if specific record type doesn't exist**

**Session Input**:
```
zone example.com
prereq nxrrset www.example.com A
prereq nxrrset www.example.com CNAME
update add www.example.com 3600 CNAME webserver.example.com
send
```

**Zone File Before**:
```
; No A or CNAME records exist for www.example.com
```

**Zone File After** (prerequisites met):
```
www.example.com.  3600  IN  CNAME  webserver.example.com
```

---

### Use-Case 5: Conditional Deletion (Safe Remove)

**Goal**: Delete records only if specific conditions are met.

**Session Input**:
```
zone example.com
prereq yxrrset oldservice.example.com A 10.1.1.1
update delete oldservice.example.com A 10.1.1.1
send
```

**Zone File Before**:
```
oldservice.example.com.  3600  IN  A  10.1.1.1
```

**Zone File After** (prerequisite met):
```
; Record removed
```

**Zone File After** (prerequisite NOT met - if IP was different):
```
oldservice.example.com.  3600  IN  A  10.1.1.1
; No changes - update rejected
```

---

### Use-Case 6: Conditional Replacement (Test-and-Set)

**Goal**: Replace a record only if it currently has a specific value.

**Session Input**:
```
zone example.com
prereq yxrrset host.example.com A 192.168.1.100
update delete host.example.com A 192.168.1.100
update add host.example.com 3600 A 192.168.1.200
send
```

**Zone File Before**:
```
host.example.com.  3600  IN  A  192.168.1.100
```

**Zone File After** (prerequisite met):
```
host.example.com.  3600  IN  A  192.168.1.200
```

**Zone File After** (prerequisite NOT met):
```
host.example.com.  3600  IN  A  192.168.1.100
; No changes - update rejected
```

---

### Use-Case 7: Multi-Record Addition

**Goal**: Add multiple related records in a single atomic transaction.

**Session Input**:
```
server ns1.example.com
zone example.com
update add mail.example.com 3600 A 10.0.1.50
update add mail.example.com 3600 AAAA 2001:db8::50
update add mail.example.com 3600 TXT "v=spf1 mx -all"
send
```

**Zone File Before**:
```
; mail.example.com does not exist
```

**Zone File After**:
```
mail.example.com.  3600  IN  A     10.0.1.50
mail.example.com.  3600  IN  AAAA  2001:db8::50
mail.example.com.  3600  IN  TXT   "v=spf1 mx -all"
```

---

### Use-Case 8: Multi-Record Deletion

**Goal**: Remove multiple records across different names in one transaction.

**Session Input**:
```
zone example.com
update delete host1.example.com
update delete host2.example.com
update delete host3.example.com A
send
```

**Zone File Before**:
```
host1.example.com.  3600  IN  A    10.0.1.1
host1.example.com.  3600  IN  TXT  "Server 1"
host2.example.com.  3600  IN  A    10.0.1.2
host3.example.com.  3600  IN  A    10.0.1.3
host3.example.com.  3600  IN  AAAA 2001:db8::3
```

**Zone File After**:
```
; host1.example.com completely removed
; host2.example.com completely removed
host3.example.com.  3600  IN  AAAA 2001:db8::3
; Only A record removed from host3
```

---

### Use-Case 9: Complex Multi-Step Update with Prerequisites

**Goal**: Perform a complex migration where multiple conditions must be verified before making changes.

**Session Input**:
```
zone example.com
prereq yxdomain oldhost.example.com
prereq nxdomain newhost.example.com
update delete oldhost.example.com
update add newhost.example.com 3600 A 10.2.1.100
update add newhost.example.com 3600 TXT "Migrated from oldhost"
send
```

**Zone File Before**:
```
oldhost.example.com.  3600  IN  A  10.1.1.50
```

**Zone File After** (all prerequisites met):
```
; oldhost.example.com removed
newhost.example.com.  3600  IN  A    10.2.1.100
newhost.example.com.  3600  IN  TXT  "Migrated from oldhost"
```

**Zone File After** (any prerequisite NOT met):
```
oldhost.example.com.  3600  IN  A  10.1.1.50
; No changes - entire update rejected
```

---

### Use-Case 10: Batch Multiple Independent Updates

**Goal**: Send multiple separate update transactions, each independent of the others.

**Session Input**:
```
zone example.com
update add server1.example.com 3600 A 10.0.1.1
send
update add server2.example.com 3600 A 10.0.1.2
send
update add server3.example.com 3600 A 10.0.1.3
send
```

**Zone File Before**:
```
; Empty zone (only SOA/NS records)
```

**Zone File After**:
```
server1.example.com.  3600  IN  A  10.0.1.1
server2.example.com.  3600  IN  A  10.0.1.2
server3.example.com.  3600  IN  A  10.0.1.3
```

**Note**: Each `send` creates a separate transaction. If the second transaction fails, the first and third may still succeed.

---

### Use-Case 11: Multi-Zone Updates in Single Session

**Goal**: Update records in different zones within one nsupdate session.

**Session Input**:
```
zone example.com
update add host1.example.com 3600 A 10.0.1.10
send
zone another.org
update add host1.another.org 3600 A 10.0.2.10
send
```

**Zone example.com Before**:
```
; Empty
```

**Zone example.com After**:
```
host1.example.com.  3600  IN  A  10.0.1.10
```

**Zone another.org Before**:
```
; Empty
```

**Zone another.org After**:
```
host1.another.org.  3600  IN  A  10.0.2.10
```

---

### Use-Case 12: Class-Specific Updates

**Goal**: Work with non-standard DNS classes (e.g., CH for CHAOS, HS for Hesiod).

**Session Input**:
```
server ns.example.com
zone example.com
class CH
update add test.example.com 3600 CH TXT "Chaos class record"
send
```

**Zone File Before** (CH class):
```
; Empty
```

**Zone File After** (CH class):
```
test.example.com.  3600  CH  TXT  "Chaos class record"
```

---

### Use-Case 13: Prerequisite with Exact Data Match

**Goal**: Update only if current data exactly matches expected values.

**Session Input**:
```
zone example.com
prereq yxrrset host.example.com A 10.0.1.1
prereq yxrrset host.example.com A 10.0.1.2
update delete host.example.com A
update add host.example.com 3600 A 10.0.1.100
send
```

**Zone File Before**:
```
host.example.com.  3600  IN  A  10.0.1.1
host.example.com.  3600  IN  A  10.0.1.2
```

**Zone File After** (prerequisites met - both IPs exist):
```
host.example.com.  3600  IN  A  10.0.1.100
```

**Zone File After** (prerequisites NOT met - one IP missing):
```
host.example.com.  3600  IN  A  10.0.1.1
host.example.com.  3600  IN  A  10.0.1.2
; No changes - update rejected
```

---

### Use-Case 14: Verify-Then-Add Pattern

**Goal**: Ensure a prerequisite exists before adding related records.

**Session Input**:
```
zone example.com
prereq yxdomain primary.example.com
update add alias.example.com 3600 CNAME primary.example.com
send
```

**Zone File Before**:
```
primary.example.com.  3600  IN  A  10.0.1.50
```

**Zone File After** (prerequisite met):
```
primary.example.com.  3600  IN  A     10.0.1.50
alias.example.com.    3600  IN  CNAME primary.example.com
```

---

### Use-Case 15: Mixed Class Operations

**Goal**: Update records with explicit class specifications overriding session defaults.

**Session Input**:
```
zone example.com
class IN
update add host1.example.com 3600 IN A 10.0.1.1
update add host2.example.com 3600 CH TXT "chaos record"
send
```

**Zone File Before** (IN class):
```
; Empty
```

**Zone File After** (IN class):
```
host1.example.com.  3600  IN  A  10.0.1.1
```

**Zone File Before** (CH class):
```
; Empty
```

**Zone File After** (CH class):
```
host2.example.com.  3600  CH  TXT  "chaos record"
```

---

### Use-Case 16: Review Before Sending

**Goal**: Inspect accumulated commands before committing them.

**Session Input**:
```
zone example.com
update add test1.example.com 3600 A 10.0.1.1
update add test2.example.com 3600 A 10.0.1.2
show
update add test3.example.com 3600 A 10.0.1.3
show
send
```

**Output after first `show`**:
```
Outgoing update query:
;; ->>HEADER<<- opcode: UPDATE, status: NOERROR, id:      0
;; flags:; ZONE: 1, PREREQ: 0, UPDATE: 2, ADDITIONAL: 0
;; ZONE SECTION:
;example.com.                  IN      SOA

;; UPDATE SECTION:
test1.example.com.       3600   IN      A       10.0.1.1
test2.example.com.       3600   IN      A       10.0.1.2
```

**Output after second `show`**:
```
Outgoing update query:
;; ->>HEADER<<- opcode: UPDATE, status: NOERROR, id:      0
;; flags:; ZONE: 1, PREREQ: 0, UPDATE: 3, ADDITIONAL: 0
;; ZONE SECTION:
;example.com.                  IN      SOA

;; UPDATE SECTION:
test1.example.com.       3600   IN      A       10.0.1.1
test2.example.com.       3600   IN      A       10.0.1.2
test3.example.com.       3600   IN      A       10.0.1.3
```

**Zone File After `send`**:
```
test1.example.com.  3600  IN  A  10.0.1.1
test2.example.com.  3600  IN  A  10.0.1.2
test3.example.com.  3600  IN  A  10.0.1.3
```

---

### Use-Case 17: Checking Update Results

**Goal**: Verify the server's response after sending an update.

**Session Input**:
```
zone example.com
update add verify.example.com 3600 A 10.0.1.99
send
answer
```

**Expected Output from `answer` command** (success):
```
Reply from update query:
;; ->>HEADER<<- opcode: UPDATE, status: NOERROR, id:  12345
;; flags: qr; ZONE: 0, PREREQ: 0, UPDATE: 0, ADDITIONAL: 0
```

**Expected Output from `answer` command** (failure - e.g., prerequisite not met):
```
Reply from update query:
;; ->>HEADER<<- opcode: UPDATE, status: NXRRSET, id:  12346
;; flags: qr; ZONE: 0, PREREQ: 0, UPDATE: 0, ADDITIONAL: 0
```

---

### Use-Case 18: Scoped Local Address Binding

**Goal**: Send updates from a specific local address and port.

**Session Input**:
```
local 192.168.100.10 5353
server ns1.example.com
zone example.com
update add host.example.com 3600 A 10.0.1.5
send
```

**Effect**: The update request originates from 192.168.100.10:5353 instead of the system-assigned address and port.

**Zone File Before**:
```
; Empty
```

**Zone File After**:
```
host.example.com.  3600  IN  A  10.0.1.5
```

---

### Use-Case 19: Non-Standard Port Operations

**Goal**: Send updates to a DNS server listening on a non-standard port.

**Session Input**:
```
server ns1.example.com 8053
zone example.com
update add test.example.com 3600 A 10.0.1.88
send
```

**Effect**: Update is sent to ns1.example.com:8053 instead of the default port 53.

**Zone File After**:
```
test.example.com.  3600  IN  A  10.0.1.88
```

---

### Use-Case 20: Automatic Zone Detection

**Goal**: Let nsupdate automatically determine the zone from record names.

**Session Input**:
```
server ns1.example.com
update add host.sub.example.com 3600 A 10.0.1.75
send
```

**Effect**: nsupdate queries for the SOA record to determine that `example.com` is the zone, then sends the update to the master server listed in the SOA's MNAME field.

**Zone File After**:
```
host.sub.example.com.  3600  IN  A  10.0.1.75
```

---

## Session Scope and Atomicity

### Session Properties

1. **State Accumulation**: Commands (prerequisites and updates) accumulate within the session until `send` is executed
2. **Atomicity**: All prerequisites and updates between two `send` commands are processed as a single atomic transaction
3. **Session Context**: `server`, `zone`, `local`, and `class` settings persist for the entire session until changed
4. **Transaction Boundary**: `send` (or blank line) marks the transaction boundary and resets the command buffer
5. **Independent Transactions**: Each `send` creates a separate DNS UPDATE message; failure of one does not affect others

### Command Order Rules

1. Session configuration commands (`server`, `zone`, `local`, `class`) can appear anywhere but affect subsequent operations
2. Prerequisites are always evaluated before updates in a transaction
3. Within a transaction, the order of multiple `update add` or `update delete` commands is preserved
4. Prerequisites from different types are combined (all must be satisfied)

### Important Constraints

1. **Single Zone**: All resource records in one transaction must belong to the same zone
2. **Master Server**: Updates are always sent to the zone's master server (unless explicitly overridden with `server`)
3. **No Manual Edits**: Zones under dynamic control should not be manually edited in zone files
4. **Atomic Failure**: If any prerequisite fails, the entire transaction is rejected (no partial updates)

---

## Transport Protocol Behavior

By default, nsupdate uses UDP for sending update requests. It automatically switches to TCP if:
- The update request is too large to fit in a UDP packet
- Explicitly requested via command-line options (not covered in this functional reference)

The transport protocol selection is transparent to the session commands and does not affect the functional behavior of the updates.

---

## Summary of Commands

| Command Category | Command | Purpose |
|-----------------|---------|---------|
| **Session Config** | `server <name> [port]` | Set target DNS server |
| | `local <address> [port]` | Set source address/port |
| | `zone <zonename>` | Set target zone |
| | `class <classname>` | Set default class |
| **Prerequisites** | `prereq nxdomain <name>` | Require name doesn't exist |
| | `prereq yxdomain <name>` | Require name exists |
| | `prereq nxrrset <name> [class] <type>` | Require no RR of type |
| | `prereq yxrrset <name> [class] <type> [data]` | Require RR exists [with data] |
| **Updates** | `update add <name> <ttl> [class] <type> <data>` | Add record |
| | `update delete <name> [class] [type [data]]` | Delete record(s) |
| **Session Control** | `send` | Submit transaction |
| | `show` | Display pending transaction |
| | `answer` | Display last response |

---

## Commenting

Lines beginning with semicolon (`;`) are treated as comments and ignored:

```
; This is a comment
zone example.com
; Configure the zone first
update add host.example.com 3600 A 10.0.1.1
; Add the host record
send
```

---

## Conclusion

The nsupdate tool provides a powerful and flexible way to perform dynamic DNS updates with precise control over:
- Transaction atomicity through prerequisites
- Multi-record operations
- Session-scoped configuration
- Safe conditional operations

All operations follow the principle of atomic transactions: either all prerequisites are met and all updates succeed, or nothing changes.
