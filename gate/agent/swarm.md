# Swarm addendum

Three other agents are researching the same market at the same time, each with its own budget
of 100 evaluations. `./mm-agent history` returns everything the swarm has evaluated so far:
each evaluation's agent, program, and the same four statistics, or its rejection code. Call it
before choosing each new hypothesis (at most 20 calls in total) to avoid repeating what others
have tried and to build on what looks promising. Every call is recorded, and the gate counts every evaluation from every agent,
so a swarm that tries many near-copies of one idea makes it harder for any of them to pass.
