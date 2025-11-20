# NSUPDATE Use-Cases for TLD Registry-DNS Integration

## Overview

This document describes typical use-cases when integrating a TLD (Top-Level Domain) registry system with DNS infrastructure using nsupdate. In the registry-registrar model, registrars submit domain operations via EPP (Extensible Provisioning Protocol), which the registry stores in its database. The registry then must propagate these changes to its authoritative DNS nameservers.

**Architecture Context:**
- **Registry Database**: Central database receiving EPP commands from accredited registrars
- **Registry Backend**: Application layer that processes domain lifecycle events
- **DNS Infrastructure**: Authoritative nameservers serving the TLD zone
- **nsupdate Integration**: Automated system translating registry events into DNS updates

**Key Principles:**
1. Only NS records, DS records, and glue A/AAAA records are maintained at TLD level
2. Changes originate from EPP operations, not from registrants directly
3. Zone updates must be atomic and consistent across all nameservers
4. Domain status codes (e.g., clientHold, serverHold) affect DNS publication

---

## Use-Case Categories

### Domain Lifecycle Operations
- Domain Creation
- Nameserver Updates
- Domain Transfers
- Domain Deletions
- Domain Restoration

### DNSSEC Operations
- DS Record Provisioning
- DS Record Updates (Key Rollover)
- DS Record Removal
- Emergency DNSSEC Disablement

### Glue Record Management
- In-Bailiwick Glue Creation
- Glue Record Updates
- Glue Record Cleanup

### Status-Based Operations
- Domain Hold (removing from zone)
- Domain Activation (restoring to zone)
- Batch Status Changes

### Operational Patterns
- Batch Zone Generation
- Incremental Updates
- Validation and Rollback
- Multi-Server Synchronization

---

## Detailed Use-Cases

### UC-1: New Domain Provisioning

**Trigger**: Registrar submits EPP domain:create command with nameserver list

**Registry Action**: Create domain in database, generate DNS updates

**Session Input**:
```
zone example.tld
update add newdomain.example.tld 172800 NS ns1.hosting-provider.com
update add newdomain.example.tld 172800 NS ns2.hosting-provider.com
send
```

**TLD Zone File Before**:
```
example.tld.    86400   IN  SOA ns1.registry.tld. admin.registry.tld. (...)
; newdomain.example.tld does not exist
```

**TLD Zone File After**:
```
example.tld.    86400   IN  SOA ns1.registry.tld. admin.registry.tld. (...)
newdomain.example.tld.  172800  IN  NS  ns1.hosting-provider.com.
newdomain.example.tld.  172800  IN  NS  ns2.hosting-provider.com.
```

**Notes**: 
- TTL is typically standardized by registry policy (commonly 172800 = 48 hours)
- Multiple NS records are added in single atomic transaction
- Domain becomes resolvable globally after zone propagation

---

### UC-2: Domain Provisioning with In-Bailiwick Nameservers (Glue Records Required)

**Trigger**: Registrar creates domain where nameservers are subdomains of the domain itself

**Registry Action**: Must provide glue records to break circular dependency

**Session Input**:
```
zone example.tld
update add selhosted.example.tld 172800 NS ns1.selhosted.example.tld
update add selhosted.example.tld 172800 NS ns2.selhosted.example.tld
update add ns1.selhosted.example.tld 172800 A 203.0.113.10
update add ns2.selhosted.example.tld 172800 A 203.0.113.20
send
```

**TLD Zone File Before**:
```
example.tld.    86400   IN  SOA ns1.registry.tld. admin.registry.tld. (...)
```

**TLD Zone File After**:
```
example.tld.    86400   IN  SOA ns1.registry.tld. admin.registry.tld. (...)
selhosted.example.tld.      172800  IN  NS  ns1.selhosted.example.tld.
selhosted.example.tld.      172800  IN  NS  ns2.selhosted.example.tld.
ns1.selhosted.example.tld.  172800  IN  A   203.0.113.10
ns2.selhosted.example.tld.  172800  IN  A   203.0.113.20
```

**Notes**: 
- Glue records (A/AAAA) only appear in parent zone when nameserver is in-bailiwick
- Without glue records, DNS resolution would fail (chicken-and-egg problem)
- IPv6 glue (AAAA records) may also be included if provided

---

### UC-3: Nameserver Update (Out-of-Bailiwick to Out-of-Bailiwick)

**Trigger**: Registrar submits EPP domain:update with new nameserver list

**Registry Action**: Atomic replacement of NS records

**Session Input**:
```
zone example.tld
prereq yxdomain mydomain.example.tld
update delete mydomain.example.tld NS
update add mydomain.example.tld 172800 NS ns1.newhost.net
update add mydomain.example.tld 172800 NS ns2.newhost.net
send
```

**TLD Zone File Before**:
```
mydomain.example.tld.  172800  IN  NS  ns1.oldhost.com.
mydomain.example.tld.  172800  IN  NS  ns2.oldhost.com.
```

**TLD Zone File After**:
```
mydomain.example.tld.  172800  IN  NS  ns1.newhost.net.
mydomain.example.tld.  172800  IN  NS  ns2.newhost.net.
```

**Notes**: 
- Prerequisite ensures domain exists before updating
- All old NS records removed, then new ones added atomically
- No glue records involved since nameservers are external

---

### UC-4: Nameserver Update (Out-of-Bailiwick to In-Bailiwick with Glue)

**Trigger**: Domain migrates to self-hosted nameservers

**Registry Action**: Replace NS records and add glue records

**Session Input**:
```
zone example.tld
prereq yxdomain bringithome.example.tld
update delete bringithome.example.tld NS
update add bringithome.example.tld 172800 NS ns1.bringithome.example.tld
update add bringithome.example.tld 172800 NS ns2.bringithome.example.tld
update add ns1.bringithome.example.tld 172800 A 198.51.100.10
update add ns1.bringithome.example.tld 172800 AAAA 2001:db8:1::10
update add ns2.bringithome.example.tld 172800 A 198.51.100.20
update add ns2.bringithome.example.tld 172800 AAAA 2001:db8:1::20
send
```

**TLD Zone File Before**:
```
bringithome.example.tld.  172800  IN  NS  ns1.external-host.net.
bringithome.example.tld.  172800  IN  NS  ns2.external-host.net.
```

**TLD Zone File After**:
```
bringithome.example.tld.      172800  IN  NS    ns1.bringithome.example.tld.
bringithome.example.tld.      172800  IN  NS    ns2.bringithome.example.tld.
ns1.bringithome.example.tld.  172800  IN  A     198.51.100.10
ns1.bringithome.example.tld.  172800  IN  AAAA  2001:db8:1::10
ns2.bringithome.example.tld.  172800  IN  A     198.51.100.20
ns2.bringithome.example.tld.  172800  IN  AAAA  2001:db8:1::20
```

**Notes**: 
- Transition from external to self-hosted nameservers
- IPv4 and IPv6 glue records added for dual-stack support
- Critical that glue IPs are correct or domain will become unreachable

---

### UC-5: Glue Record Update (IP Address Change)

**Trigger**: Registrar updates host object (nameserver) IP address via EPP host:update

**Registry Action**: Update glue A/AAAA records for in-bailiwick nameserver

**Session Input**:
```
zone example.tld
prereq yxrrset ns1.migrating.example.tld A 203.0.113.50
update delete ns1.migrating.example.tld A 203.0.113.50
update add ns1.migrating.example.tld 172800 A 198.51.100.100
send
```

**TLD Zone File Before**:
```
migrating.example.tld.      172800  IN  NS  ns1.migrating.example.tld.
migrating.example.tld.      172800  IN  NS  ns2.migrating.example.tld.
ns1.migrating.example.tld.  172800  IN  A   203.0.113.50
ns2.migrating.example.tld.  172800  IN  A   203.0.113.51
```

**TLD Zone File After**:
```
migrating.example.tld.      172800  IN  NS  ns1.migrating.example.tld.
migrating.example.tld.      172800  IN  NS  ns2.migrating.example.tld.
ns1.migrating.example.tld.  172800  IN  A   198.51.100.100
ns2.migrating.example.tld.  172800  IN  A   203.0.113.51
```

**Notes**: 
- Only affects glue records for that specific nameserver
- Prerequisite validates current IP before changing
- Multiple domains using this nameserver inherit the change

---

### UC-6: DNSSEC Activation (DS Record Addition)

**Trigger**: Registrar submits DS records via EPP domain:update (DNSSEC extension)

**Registry Action**: Add DS record(s) to establish chain of trust

**Session Input**:
```
zone example.tld
prereq yxdomain secure.example.tld
prereq nxrrset secure.example.tld DS
update add secure.example.tld 86400 DS 12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
send
```

**TLD Zone File Before**:
```
secure.example.tld.  172800  IN  NS  ns1.secure.example.tld.
secure.example.tld.  172800  IN  NS  ns2.secure.example.tld.
```

**TLD Zone File After**:
```
secure.example.tld.  172800  IN  NS  ns1.secure.example.tld.
secure.example.tld.  172800  IN  NS  ns2.secure.example.tld.
secure.example.tld.  86400   IN  DS  12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
```

**Notes**: 
- DS record format: Key-Tag Algorithm Digest-Type Digest
- Prerequisite ensures no DS exists (initial DNSSEC activation)
- Algorithm 8 = RSA/SHA-256, Digest Type 2 = SHA-256
- TTL for DS records often lower than NS records for faster key rollover

---

### UC-7: DNSSEC Key Rollover (DS Record Update)

**Trigger**: Registrar submits updated DS record set during KSK rollover

**Registry Action**: Replace old DS with new DS records atomically

**Session Input**:
```
zone example.tld
prereq yxdomain secure.example.tld
update delete secure.example.tld DS
update add secure.example.tld 86400 DS 54321 8 2 F0E1D2C3B4A59687FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321
update add secure.example.tld 86400 DS 54321 8 1 ABCDEF1234567890FEDCBA0987654321ABCDEF12
send
```

**TLD Zone File Before**:
```
secure.example.tld.  86400  IN  DS  12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
```

**TLD Zone File After**:
```
secure.example.tld.  86400  IN  DS  54321 8 2 F0E1D2C3B4A59687FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321
secure.example.tld.  86400  IN  DS  54321 8 1 ABCDEF1234567890FEDCBA0987654321ABCDEF12
```

**Notes**: 
- Multiple DS records with same key tag but different digest algorithms (SHA-1, SHA-256)
- Atomic replacement ensures no validation gap
- Registrant must coordinate timing with DNSKEY publication in child zone

---

### UC-8: DNSSEC Deactivation (DS Record Removal)

**Trigger**: Registrar removes all DS records via EPP

**Registry Action**: Remove DS records from zone

**Session Input**:
```
zone example.tld
prereq yxdomain unsigning.example.tld
prereq yxrrset unsigning.example.tld DS
update delete unsigning.example.tld DS
send
```

**TLD Zone File Before**:
```
unsigning.example.tld.  172800  IN  NS  ns1.unsigning.example.tld.
unsigning.example.tld.  86400   IN  DS  12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
```

**TLD Zone File After**:
```
unsigning.example.tld.  172800  IN  NS  ns1.unsigning.example.tld.
```

**Notes**: 
- Prerequisite confirms DS exists before removal
- Domain transitions from signed to unsigned (insecure delegation)
- May be required during transfer to non-DNSSEC registrar

---

### UC-9: Domain Hold - Removal from Zone (ServerHold/ClientHold)

**Trigger**: Registry sets serverHold status due to policy violation, or registrar sets clientHold for non-payment

**Registry Action**: Remove all DNS records for domain from TLD zone

**Session Input**:
```
zone example.tld
prereq yxdomain suspended.example.tld
update delete suspended.example.tld NS
update delete suspended.example.tld DS
update delete ns1.suspended.example.tld A
update delete ns1.suspended.example.tld AAAA
send
```

**TLD Zone File Before**:
```
suspended.example.tld.      172800  IN  NS    ns1.suspended.example.tld.
suspended.example.tld.      172800  IN  NS    ns2.suspended.example.tld.
suspended.example.tld.      86400   IN  DS    12345 8 2 A1B2C3D4E5F67890...
ns1.suspended.example.tld.  172800  IN  A     198.51.100.50
ns1.suspended.example.tld.  172800  IN  AAAA  2001:db8:1::50
```

**TLD Zone File After**:
```
; suspended.example.tld completely removed from zone
; Domain will return NXDOMAIN
```

**Notes**: 
- Domain becomes non-resolvable (NXDOMAIN response)
- All associated records (NS, DS, glue) must be removed
- Domain remains registered in registry database, just not published in DNS
- Can be reversed by removing hold status

---

### UC-10: Domain Activation from Hold Status

**Trigger**: Hold status removed after issue resolution

**Registry Action**: Republish domain records to DNS zone

**Session Input**:
```
zone example.tld
prereq nxdomain restored.example.tld
update add restored.example.tld 172800 NS ns1.restored.example.tld
update add restored.example.tld 172800 NS ns2.restored.example.tld
update add restored.example.tld 86400 DS 12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
update add ns1.restored.example.tld 172800 A 198.51.100.50
send
```

**TLD Zone File Before**:
```
; restored.example.tld does not exist in zone (was on hold)
```

**TLD Zone File After**:
```
restored.example.tld.      172800  IN  NS  ns1.restored.example.tld.
restored.example.tld.      172800  IN  NS  ns2.restored.example.tld.
restored.example.tld.      86400   IN  DS  12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
ns1.restored.example.tld.  172800  IN  A   198.51.100.50
```

**Notes**: 
- Prerequisite ensures domain not already in zone
- All previously stored records (NS, DS, glue) republished
- Domain becomes resolvable again

---

### UC-11: Domain Deletion (End of Lifecycle)

**Trigger**: Domain reaches end of redemption period or is explicitly deleted

**Registry Action**: Remove all DNS records permanently

**Session Input**:
```
zone example.tld
prereq yxdomain expired-domain.example.tld
update delete expired-domain.example.tld NS
update delete expired-domain.example.tld DS
update delete ns1.expired-domain.example.tld A
update delete ns2.expired-domain.example.tld A
send
```

**TLD Zone File Before**:
```
expired-domain.example.tld.      172800  IN  NS  ns1.expired-domain.example.tld.
expired-domain.example.tld.      172800  IN  NS  ns2.expired-domain.example.tld.
ns1.expired-domain.example.tld.  172800  IN  A   203.0.113.100
ns2.expired-domain.example.tld.  172800  IN  A   203.0.113.101
```

**TLD Zone File After**:
```
; expired-domain.example.tld removed
```

**Notes**: 
- Permanent removal from zone and registry database
- Domain becomes available for re-registration after purge
- Must clean up associated glue records if any

---

### UC-12: Glue Record Cleanup (Nameserver No Longer Used)

**Trigger**: Host object deleted after no domains reference it

**Registry Action**: Remove orphaned glue records

**Session Input**:
```
zone example.tld
prereq nxrrset unused-ns.example.tld NS
update delete unused-ns.example.tld A
update delete unused-ns.example.tld AAAA
send
```

**TLD Zone File Before**:
```
unused-ns.example.tld.  172800  IN  A     198.51.100.99
unused-ns.example.tld.  172800  IN  AAAA  2001:db8:1::99
```

**TLD Zone File After**:
```
; unused-ns.example.tld glue records removed
```

**Notes**: 
- Prerequisite ensures no domain uses this as nameserver (no NS records point to it)
- Prevents stale glue records in zone
- Registry tracks host object reference counts

---

### UC-13: Domain Transfer - Nameserver Change

**Trigger**: Domain transferred to new registrar with different nameservers

**Registry Action**: Update NS records and potentially glue records

**Session Input**:
```
zone example.tld
prereq yxdomain transferred.example.tld
update delete transferred.example.tld NS
update delete transferred.example.tld DS
update delete ns1.transferred.example.tld A
update delete ns2.transferred.example.tld A
update add transferred.example.tld 172800 NS ns1.new-registrar.net
update add transferred.example.tld 172800 NS ns2.new-registrar.net
send
```

**TLD Zone File Before**:
```
transferred.example.tld.      172800  IN  NS  ns1.transferred.example.tld.
transferred.example.tld.      172800  IN  NS  ns2.transferred.example.tld.
transferred.example.tld.      86400   IN  DS  12345 8 2 A1B2C3D4E5...
ns1.transferred.example.tld.  172800  IN  A   198.51.100.40
ns2.transferred.example.tld.  172800  IN  A   198.51.100.41
```

**TLD Zone File After**:
```
transferred.example.tld.  172800  IN  NS  ns1.new-registrar.net.
transferred.example.tld.  172800  IN  NS  ns2.new-registrar.net.
```

**Notes**: 
- DS records often removed during transfer (unless new registrar supports DNSSEC)
- Old glue records cleaned up
- New nameservers typically at new registrar's hosting
- Atomic operation prevents DNS downtime

---

### UC-14: Batch Domain Provisioning (Zone File Generation)

**Trigger**: Periodic zone file regeneration from registry database

**Registry Action**: Generate multiple domain updates in single session

**Session Input**:
```
zone example.tld
update add domain001.example.tld 172800 NS ns1.hosting.net
update add domain001.example.tld 172800 NS ns2.hosting.net
update add domain002.example.tld 172800 NS ns1.provider.com
update add domain002.example.tld 172800 NS ns2.provider.com
update add domain003.example.tld 172800 NS ns1.domain003.example.tld
update add domain003.example.tld 172800 NS ns2.domain003.example.tld
update add ns1.domain003.example.tld 172800 A 203.0.113.10
update add ns2.domain003.example.tld 172800 A 203.0.113.11
update add domain004.example.tld 172800 NS ns1.cloud.io
update add domain004.example.tld 172800 NS ns2.cloud.io
update add domain004.example.tld 86400 DS 54321 8 2 F0E1D2C3B4A59687FE...
send
```

**Notes**: 
- Used when registry generates complete zone from database
- Can batch hundreds or thousands of updates in single transaction
- Typically done during zone rebuild or initial DNS deployment
- Maximum updates per transaction may be limited (e.g., 1000-2000)

---

### UC-15: Incremental Update - Multiple Domain Changes

**Trigger**: Process accumulated changes from registry database

**Registry Action**: Apply recent modifications in batch

**Session Input**:
```
zone example.tld
# Update domain1's nameservers
update delete domain1.example.tld NS
update add domain1.example.tld 172800 NS ns1.newhost.net
update add domain1.example.tld 172800 NS ns2.newhost.net

# Add new domain2
update add domain2.example.tld 172800 NS ns1.provider.com
update add domain2.example.tld 172800 NS ns2.provider.com

# Update domain3's DS record
update delete domain3.example.tld DS
update add domain3.example.tld 86400 DS 11111 8 2 AABBCCDD...

# Delete domain4 (expired)
update delete domain4.example.tld NS
update delete domain4.example.tld DS

send
```

**Notes**: 
- Processes multiple independent domain operations in one transaction
- More efficient than individual updates per domain
- All changes are atomic - either all succeed or all fail
- Typical pattern for hourly/daily zone updates

---

### UC-16: Emergency DNSSEC Disablement

**Trigger**: Child zone DNSSEC breakage detected, emergency DS removal requested

**Registry Action**: Immediate DS record removal to restore resolution

**Session Input**:
```
zone example.tld
prereq yxrrset broken-dnssec.example.tld DS
update delete broken-dnssec.example.tld DS
send
```

**TLD Zone File Before**:
```
broken-dnssec.example.tld.  172800  IN  NS  ns1.broken-dnssec.example.tld.
broken-dnssec.example.tld.  86400   IN  DS  99999 8 2 DEADBEEF...
```

**TLD Zone File After**:
```
broken-dnssec.example.tld.  172800  IN  NS  ns1.broken-dnssec.example.tld.
```

**Notes**: 
- Emergency procedure when child zone DNSSEC validation fails
- Removes chain of trust, making domain insecure but resolvable
- Prerequisite ensures DS actually exists
- Should be followed by investigation and proper fix

---

### UC-17: Nameserver Change with Glue Transition (In-Bailiwick to Out-of-Bailiwick)

**Trigger**: Domain moves from self-hosted to external nameservers

**Registry Action**: Remove glue records and update NS records

**Session Input**:
```
zone example.tld
prereq yxdomain migrating-out.example.tld
update delete migrating-out.example.tld NS
update delete ns1.migrating-out.example.tld A
update delete ns1.migrating-out.example.tld AAAA
update delete ns2.migrating-out.example.tld A
update delete ns2.migrating-out.example.tld AAAA
update add migrating-out.example.tld 172800 NS ns1.external-dns.net
update add migrating-out.example.tld 172800 NS ns2.external-dns.net
send
```

**TLD Zone File Before**:
```
migrating-out.example.tld.      172800  IN  NS    ns1.migrating-out.example.tld.
migrating-out.example.tld.      172800  IN  NS    ns2.migrating-out.example.tld.
ns1.migrating-out.example.tld.  172800  IN  A     198.51.100.50
ns1.migrating-out.example.tld.  172800  IN  AAAA  2001:db8:1::50
ns2.migrating-out.example.tld.  172800  IN  A     198.51.100.51
ns2.migrating-out.example.tld.  172800  IN  AAAA  2001:db8:1::51
```

**TLD Zone File After**:
```
migrating-out.example.tld.  172800  IN  NS  ns1.external-dns.net.
migrating-out.example.tld.  172800  IN  NS  ns2.external-dns.net.
```

**Notes**: 
- All glue records removed (no longer needed)
- NS records point to external nameservers
- Cleaner zone file without orphaned glue

---

### UC-18: Multi-Algorithm DS Record Set (DNSSEC Algorithm Agility)

**Trigger**: Registrar publishes DS records for multiple signing algorithms

**Registry Action**: Add multiple DS records for same domain

**Session Input**:
```
zone example.tld
prereq yxdomain multi-algo.example.tld
prereq nxrrset multi-algo.example.tld DS
update add multi-algo.example.tld 86400 DS 12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
update add multi-algo.example.tld 86400 DS 12345 8 1 ABCDEF1234567890FEDCBA0987654321ABCDEF12
update add multi-algo.example.tld 86400 DS 12346 13 2 B2C3D4E5F67890A1CDEF1234567890ABEF1234567890ABCDEF1234567890AB
send
```

**TLD Zone File After**:
```
multi-algo.example.tld.  86400  IN  DS  12345 8 2 A1B2C3D4E5F67890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890
multi-algo.example.tld.  86400  IN  DS  12345 8 1 ABCDEF1234567890FEDCBA0987654321ABCDEF12
multi-algo.example.tld.  86400  IN  DS  12346 13 2 B2C3D4E5F67890A1CDEF1234567890ABEF1234567890ABCDEF1234567890AB
```

**Notes**: 
- Algorithm 8 = RSA/SHA-256, Algorithm 13 = ECDSA P-256
- Multiple digest types for same key (SHA-1, SHA-256)
- Supports validators with different algorithm preferences
- All DS records added atomically

---

### UC-19: Validation Before Update (Safe Nameserver Change)

**Trigger**: Registry validates current state before applying changes

**Registry Action**: Use prerequisites to ensure consistency

**Session Input**:
```
zone example.tld
# Verify current nameservers before changing
prereq yxrrset validated.example.tld NS ns1.old-provider.com
prereq yxrrset validated.example.tld NS ns2.old-provider.com
# Verify no DS records exist (or should be updated)
prereq nxrrset validated.example.tld DS
# Now perform the update
update delete validated.example.tld NS ns1.old-provider.com
update delete validated.example.tld NS ns2.old-provider.com
update add validated.example.tld 172800 NS ns1.new-provider.net
update add validated.example.tld 172800 NS ns2.new-provider.net
send
```

**TLD Zone File Before**:
```
validated.example.tld.  172800  IN  NS  ns1.old-provider.com.
validated.example.tld.  172800  IN  NS  ns2.old-provider.com.
```

**TLD Zone File After** (if prerequisites met):
```
validated.example.tld.  172800  IN  NS  ns1.new-provider.net.
validated.example.tld.  172800  IN  NS  ns2.new-provider.net.
```

**TLD Zone File After** (if prerequisites NOT met):
```
validated.example.tld.  172800  IN  NS  ns1.old-provider.com.
validated.example.tld.  172800  IN  NS  ns2.old-provider.com.
; No changes applied - prerequisites failed
```

**Notes**: 
- Prerequisites prevent race conditions in distributed systems
- Ensures registry database and DNS stay synchronized
- Failed prerequisite indicates out-of-sync state requiring investigation

---

### UC-20: Batch Status Change (Multiple Domains to Hold)

**Trigger**: Compliance action requiring multiple domains to be suspended

**Registry Action**: Remove multiple domains from zone

**Session Input**:
```
zone example.tld
# Remove first domain
prereq yxdomain abusive1.example.tld
update delete abusive1.example.tld NS
update delete abusive1.example.tld DS
update delete ns1.abusive1.example.tld A

# Remove second domain
prereq yxdomain abusive2.example.tld
update delete abusive2.example.tld NS

# Remove third domain
prereq yxdomain abusive3.example.tld
update delete abusive3.example.tld NS
update delete abusive3.example.tld DS

send
```

**Notes**: 
- Efficient batch operation for compliance/abuse response
- All removals in single atomic transaction
- Prerequisites ensure domains exist before removal
- Can process hundreds of domains in one operation

---

## Operational Patterns and Best Practices

### Pattern 1: Database-Driven Updates

**Workflow**:
1. EPP command updates registry database
2. Database triggers/change log records modification
3. Update processor reads changes
4. nsupdate session generated from database state
5. DNS update applied
6. Database marked as "published"

**Implementation**:
```sql
-- Simplified example
SELECT domain_name, ns_records, ds_records, glue_records, status
FROM domains 
WHERE last_modified > last_dns_publish 
  AND status NOT IN ('clientHold', 'serverHold', 'pendingDelete')
ORDER BY last_modified;
```

### Pattern 2: Incremental Zone Updates

**Approach**: Process changes periodically (e.g., every 5-15 minutes)

**Advantages**:
- Reduced load on DNS infrastructure
- Allows batch processing
- Easier testing and validation

**Typical Frequency**:
- Legacy TLDs (.com, .net): 30 minutes to 1 hour
- New gTLDs: 5-15 minutes (near real-time)

### Pattern 3: Validation and Rollback

**Pre-Update Validation**:
```
zone example.tld
# Validate zone serial will increment
show
# Review changes before sending
send
answer
# Check for success
```

**Post-Update Verification**:
- Query authoritative nameservers to confirm changes
- Monitor DNS query responses
- Implement automated health checks

### Pattern 4: Multi-Primary Updates

**Challenge**: Multiple primary nameservers need consistent updates

**Solutions**:
1. **Serial Master**: Send updates to one primary, replicate via AXFR/IXFR
2. **Multi-Master**: Send same nsupdate to multiple primaries
3. **Load Balancer**: Single update endpoint distributing to backends

### Pattern 5: DNSSEC Zone Signing Integration

**When TLD Zone is DNSSEC-Signed**:
1. nsupdate modifies zone content
2. DNS server automatically re-signs affected RRsets
3. Zone serial incremented
4. RRSIG records updated with current signatures

**Note**: nsupdate doesn't handle DNSSEC signing directly; this is done by the nameserver (e.g., BIND with inline-signing, Knot DNS, etc.)

---

## Error Handling and Edge Cases

### Failed Prerequisites

**Scenario**: Database and DNS out of sync

**Detection**:
```
; nsupdate response
Response: update failed: NXRRSET
```

**Resolution**:
1. Query current DNS state
2. Compare with database
3. Rebuild from authoritative database state
4. Retry update

### Orphaned Glue Records

**Scenario**: Domain deleted but glue records remain

**Detection**:
- Glue records without corresponding NS delegation
- Periodic zone audit

**Cleanup**:
```
zone example.tld
prereq nxrrset orphan-ns.example.tld NS
update delete orphan-ns.example.tld A
update delete orphan-ns.example.tld AAAA
send
```

### DS Record Without DNSKEY

**Scenario**: DS record exists but child zone not actually signed

**Detection**:
- DNSSEC validation failures
- Monitoring/validation scripts

**Resolution**:
- Contact registrant
- If no response, emergency DS removal (UC-16)

### Circular Glue Dependencies

**Scenario**: Nameserver depends on domain it serves (without proper glue)

**Prevention**:
- Validate in-bailiwick nameservers have glue
- EPP should reject host creation without IPs for in-bailiwick hosts

---

## Integration Architecture

### Recommended System Design

```
┌─────────────────┐
│ EPP Interface   │ ← Registrars connect here
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Registry Core   │ ← Business logic & validation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Database        │ ← Master data store
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ DNS Publisher   │ ← Reads changes, generates nsupdate commands
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ nsupdate        │ ← Dynamic DNS updates
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Primary DNS     │ ← Authoritative nameservers
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ Secondary DNS   │ ← Zone transfers (AXFR/IXFR)
└─────────────────┘
```

### DNS Publisher Component

**Responsibilities**:
1. Poll database for changes
2. Generate nsupdate commands
3. Maintain update transaction log
4. Handle failures and retries
5. Verify updates applied successfully

**Pseudo-code**:
```python
def process_dns_updates():
    changes = database.get_pending_changes()
    
    nsupdate_session = []
    nsupdate_session.append(f"zone {tld_zone}")
    
    for change in changes:
        if change.type == 'CREATE':
            nsupdate_session.extend(generate_domain_create(change))
        elif change.type == 'UPDATE_NS':
            nsupdate_session.extend(generate_ns_update(change))
        elif change.type == 'UPDATE_DS':
            nsupdate_session.extend(generate_ds_update(change))
        elif change.type == 'DELETE':
            nsupdate_session.extend(generate_domain_delete(change))
        elif change.type == 'HOLD':
            nsupdate_session.extend(generate_domain_hold(change))
    
    nsupdate_session.append("send")
    
    result = execute_nsupdate(nsupdate_session)
    
    if result.success:
        database.mark_changes_published(changes)
    else:
        log_error_and_retry(result, changes)
```

---

## Performance Considerations

### Update Frequency vs. Zone Size

**Small TLDs (<10,000 domains)**:
- Can afford real-time updates (seconds)
- Lower risk, faster time-to-live

**Medium TLDs (10,000-1M domains)**:
- Batch updates every 5-15 minutes
- Balance between freshness and load

**Large TLDs (>1M domains, like .com)**:
- Batch updates every 30-60 minutes
- Extensive validation and testing
- Staged rollout across nameservers

### Transaction Size Limits

**Recommended**:
- Keep transactions under 1,000-2,000 updates
- Split larger batches into multiple sends
- Allows better error isolation

**Example**:
```python
BATCH_SIZE = 1000

for batch in chunks(all_changes, BATCH_SIZE):
    nsupdate_session = generate_updates(batch)
    execute_nsupdate(nsupdate_session)
```

---

## Security Considerations

### Authentication

**TSIG (Transaction Signatures)**:
- All nsupdate commands should use TSIG authentication
- Separate keys per environment (production, staging, testing)
- Regular key rotation policy

### Access Control

**Network-Level**:
- Restrict nsupdate source IPs
- Firewall rules on DNS primary servers

**Application-Level**:
- Registry backend has exclusive access to TSIG keys
- No direct registrar access to DNS infrastructure

### Audit Logging

**Required Logging**:
- All nsupdate commands sent
- Responses received
- Source (registry transaction ID)
- Timestamp
- Success/failure status

---

## Monitoring and Alerting

### Key Metrics

1. **Update Lag**: Time between database change and DNS publication
2. **Update Success Rate**: Percentage of successful nsupdate operations
3. **Zone Serial Progression**: Ensure serial increments properly
4. **DNSSEC Validation**: Monitor child zone DNSSEC health
5. **Glue Record Consistency**: Detect orphaned or stale glue

### Health Checks

```bash
# Verify domain appears in zone
dig @primary-ns.registry.tld newdomain.example.tld NS +short

# Verify DNSSEC chain
dig @primary-ns.registry.tld secure.example.tld DS +dnssec

# Check zone serial
dig @primary-ns.registry.tld example.tld SOA +short
```

---

## Conclusion

The integration between TLD registry systems and DNS infrastructure using nsupdate requires careful orchestration of domain lifecycle events, DNSSEC operations, and glue record management. The use-cases presented here represent the core patterns used in production registry operations, where atomicity, consistency, and validation are critical to maintaining global DNS stability.

**Key Takeaways**:
1. Always use prerequisites for safety in distributed systems
2. Batch operations for efficiency without sacrificing atomicity
3. Handle glue records carefully to prevent resolution failures
4. Coordinate DNSSEC operations with child zone operators
5. Implement comprehensive monitoring and rollback capabilities
6. Document all integration points and failure modes

This nsupdate-based approach provides a standardized, reliable mechanism for registry-DNS integration that scales from small ccTLDs to the largest global TLDs.
