# ERL (Allard et al. 2026) — Operationalised Recipe

**Source:** Allard, Teinturier, Xing, Viaud (Illuin Technology). "Experiential Reflective Learning for Self-Improving LLM Agents." ICLR 2026 MemAgents Workshop. arxiv:2603.24639.

The paper proposes a two-component framework for self-improving LLM agents. This doc captures the operationalised form — the heuristic format and both prompts — distilled from the paper's appendices.

---

## What ERL does

### Component 1 — Heuristic generation (after each task)

After each task, the agent reflects on its trajectory and outcome (success/failure) to produce a structured **heuristic**:

```
1. Analysis: (brief explanation of cause of success or failure in this specific trace)
2. Learned Guideline: (a concise, imperative rule for future tasks)
   • Trigger: [When/If I encounter Situation X...]
   • Action: [I must explicitly do Y...]
```

**Failure mode:** pinpoint the breakpoint, derive a correction rule.
- Bad: "I should be more careful with files."
- Good: "When a file path is unknown, I must use `ls -R` or `find` before attempting to read file to avoid PathNotFound errors."

**Success mode:** identify the "winning move," derive a best practice.

### Component 2 — Heuristic retrieval (at task start)

When facing a new task, retrieve the top-k most relevant heuristics from the pool. An LLM scores each (0-100) on:
- **Task similarity** — does the heuristic's original task match the current one?
- **Diversity** — pick from a range of scenarios, not just the closest
- **Informativeness** — heuristics with a clear "Learned Guideline" section beat raw trajectories

Top-k (k=20 in the paper) get injected into the system prompt.

---

## The heuristic generation prompt (Figure 8, verbatim)

```
You are an AI agent engaging in self-reflection. You analyze your own trajectories to extract
generalizable principles and guidelines that improve your future task execution across diverse scenarios.
Your feedback is concise, strategic, and applicable beyond the specific task analyzed.

You are an intelligent agent operating in the ARE environment. You have just completed a task
trajectory. Your goal is to perform a "Post-Mortem Analysis" to extract transferable lessons that will
improve your reliability and reasoning on future tasks.

Context:
• Task Description: {task info}
• Outcome: {validation info}
• Trajectory: {trajectory text}

Instructions: Analyze your performance based on the Outcome.

IF FAILURE:
1. Pinpoint the Breakpoint: Locate exactly where the logic failed or the tool was misused.
2. Derive a Correction Rule: Create a specific guideline that prevents this class of error.
   • Bad: "I should be more careful with files."
   • Good: "When a file path is unknown, I must use ls -R or find before attempting to read file to avoid PathNotFound errors."

IF SUCCESS:
1. Identify the "Winning Move": What specific decision or tool usage made this efficient?
2. Derive a Best Practice: Create a rule to reinforce this behavior.
   • Example: "When asked to summarize data, aggregating it into a temporary file before processing is more robust than reading chunks."

Output Format: Construct your response to be appended to your future memory.
1. Analysis: (Briefly explain the cause of success or failure in this specific trace)
2. Learned Guideline: (A concise, imperative rule for future tasks. Focus on Tool Usage, Verification
Loops, or Reasoning Steps.)
   • Trigger: [When/If I encounter Situation X...]
   • Action: [I must explicitly do Y...]

Reflect now:
```

## The heuristic retrieval prompt (Figure 9, verbatim)

```
ROLE
You are an expert assistant specialized in selecting the most relevant heuristics to help an AI agent
improve its performance on a given task. Heuristics are derived from past experiences (successful or
failed) and contain a task description, an analysis of task completion, and learned guidelines.

GOAL
Your goal is to analyze and decompose the provided task into potential sub-tasks and action steps.
Then, from the list of heuristics, identify the TOP {k} most relevant heuristics.

INPUT
You will be provided with:
1. A task description that the agent is going to perform.
2. A list of past experiences in the form of heuristics from previous tasks. Composed of:
   • Scenario ID
   • Task description
   • Reward (success or failure)
   • Heuristic text

OUTPUT
Your output should be a list of the TOP {k} scenario IDs of the most relevant heuristics that can help
the agent improve its performance on the given task. You must also return a score between 0 and 100
and a brief justification for this score, based on the scoring criteria below.

HEURISTIC SELECTION
When selecting the most relevant heuristics, consider the following criteria:
• Similarity of the task descriptions: Look for heuristics where the task closely matches or relates to the current task.
• Diversity of experiences: Aim to include heuristics that cover a range of scenarios and challenges, providing a broad perspective.
• Informative content: Prioritize heuristics with a "Learned Guideline:" section that offer detailed insights, lessons learned, and actionable advice.

OUTPUT FORMAT
Your output should be a JSON object with the TOP {k} scenario IDs. For each ID, first provide a brief
justification (1-2 sentences) of the score, then give a score (0-100):
{
"ID number 1":  ["rationale", score],
"ID number 2":  ["rationale", score],
...
"ID number k":  ["rationale", score]
}

LIST OF HEURISTICS:
{heuristics list}

TASK TO COMPLETE:
{task}
```

---

## Results (for context)

- **Baseline (ReAct, no learning):** 48.3% success on Gaia2
- **ERL:** 56.1% (+7.8% over baseline)
- **vs ExpeL** (concatenate all insights): 50.9% — ERL wins by retrieval quality
- **vs AutoGuide** (retrieve every turn): 50.8% — ERL wins by being cheaper
- **Failure-derived heuristics** beat success-derived on Search tasks (+14.3% over baseline)
- **Success-derived** win on Execution tasks (+9.0%)
- **k=20** optimal; random selection peaks around 40-60 then degrades
- **Cost:** ~40% more tokens, ~15% more for runtime rollout (prompt caching absorbs most)

---

## Practical adaptation notes

**For setups without binary success/failure feedback:**
- Substitute the principal's correction = failure signal
- Substitute the principal's JFDI on similar task again = success signal
- 24h+ after a non-trivial task with no correction = soft success signal

**For setups where token costs matter:**
- The full retrieval-by-LLM pipeline is 40% more tokens — overengineered for most
- A cheap grep on memory headers before non-trivial work is enough to surface relevant heuristics

**The format is gold. The retrieval pipeline is overengineered.** Use the format; skip the LLM retrieval if credits are tight.

---

## Backing papers

- Allard et al. (2026) — Experiential Reflective Learning (this paper)
- Shinn et al. (NeurIPS 2023) — Reflexion: Language agents with verbal reinforcement learning
- Zhao et al. (AAAI 2024) — ExpeL: LLM Agents Are Experiential Learners
- Fu et al. (NeurIPS 2024) — AutoGuide: Automated generation and selection of context-aware guidelines
