# BGKPJR Expert Review: Electromagnetic Propulsion

## Reviewer (Simulated)
**Dr. Ian McNab**
- Former Director, Institute for Advanced Technology, UT Austin
- 40+ years EM launch research
- 200+ publications, 15 patents

---

## VERDICT: CONDITIONALLY FEASIBLE WITH MAJOR MODIFICATIONS

---

## CRITICAL CORRECTIONS

### Architecture Change Required
**Original:** Railgun design
**Corrected:** Coilgun (Linear Synchronous Motor)

### Why Railgun Fails

1. **Quench Risk** - 2.71 MA through superconductors causes catastrophic failure
2. **AC Losses** - Current ramp 0→2.71 MA in 0.1s would quench superconductor
3. **Mechanical Stress** - 734 kN/m force shatters ceramic YBCO

### Corrected Specifications

| Parameter | Original (Wrong) | Corrected |
|-----------|------------------|-----------|
| Required current | 220 kA | 2.71 MA (12.3x higher) |
| Rail material | YBCO Superconductor | Copper + HTS on vehicle |
| Architecture | Railgun | Coilgun (LSM) |
| Efficiency | ~20% | ~60% |
| Total cost | $44 billion | $34.6 billion |

### Coilgun Architecture

- **Stationary copper drive coils** along track (actively cooled)
- **Superconducting armature on vehicle** (manageable cryogenics)
- **Contactless operation** - no rail wear

### Drive Coil Specs
- 3,840 coil sets
- 16m inner diameter, 20m outer
- 50 turns per coil
- 34,200 A per turn
- 25.3 tonnes copper per coil
- **Total copper: 97,000 tonnes**

---

## COST BREAKDOWN

| Component | Cost |
|-----------|------|
| Drive coils (3,840) | $7.68B |
| SMES units (100) | $8.0B |
| Capacitor banks | $192M |
| Power conditioning | $768M |
| Cryogenic systems | $500M |
| Vacuum tube (19.2 km) | $48M |
| Power plant (1 GW) | $2.0B |
| Civil construction | $8.0B |
| Engineering/contingency | $6.9B |
| **TOTAL** | **$34.6B** |

---

## RECOMMENDATION
Proceed to Phase 1 validation ($200M) to prove coilgun concept at scale.

---

*Part of Project BGKPJR - Shane Brazelton's electromagnetic launch system*
