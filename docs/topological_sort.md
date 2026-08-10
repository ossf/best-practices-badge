# Topological Sort Analysis

I asked claude to re-review the topological sort algorithm and its
use in chief.rb, to look for problems. It's a well-known algorithm, but
it's complicated enough that a mistake might slip by.

Claude said "The algorithm is correct." and provided the following
rationale:

## Overall

The implementation at app/lib/chief.rb:187-227 uses Kahn's algorithm and is
implemented properly. Here's a detailed breakdown:

Dependency graph construction (lines 189-204)

This is correct. For each detective, it finds all other detectives in the list
 whose OUTPUTS overlap with its INPUTS, and records those as dependencies.

This means "detective X depends on detective Y if Y produces something X
needs." The sort will then ensure Y runs before X.

Kahn's algorithm (lines 206-222)

The algorithm:

1. Starts with all detectives that have zero dependencies (no_dependencies

queue)

2. Pops one off, adds it to sorted
3. Removes that detective from every other detective's dependency set
4. When a dependency set becomes empty, adds that detective to the queue
5. Repeats until the queue is empty

The recent bug fix (commit a294bf50) was critical. The original code was:

no_dependencies << dependent if deps.empty? && !sorted.include?(dependent)

The fix added !no_dependencies.include?(dependent):

if deps.empty? && !sorted.include?(dependent) &&
   !no_dependencies.include?(dependent)
  no_dependencies << dependent

end

Why this mattered: When processing a detective from the queue, the inner loop
iterates over all entries in the dependencies hash, including detectives whose
 dependency sets were already empty. Without the extra check, a detective

already waiting in no_dependencies could be added again, creating duplicates
in sorted. This would cause sorted.size != detectives.size, silently
triggering the cycle-fallback at line 226 and returning unsorted order —
defeating the entire purpose of the sort.

Cycle handling (line 226)

sorted.size == detectives.size ? sorted : detectives

If a cycle exists, some detectives will never have their dependency sets reach
 empty, so sorted will be smaller than the input. The fallback to original

order is a safe, conservative choice.

Usage in propose_changes (lines 266-285)

Correct. The pipeline is:

1. needed_outputs — determine which fields are needed
2. filter_needed_detectives — backward search to find all detectives needed

(including transitive dependencies via INPUTS)

3. topological_sort_detectives — sort that subset
4. Run each detective in order, accumulating proposals via propose_one_change

Each detective receives the best current estimates for its INPUTS (via
compute_current), which merges project data with proposals from previously-run
 detectives. The topological ordering guarantees that producers run before

consumers.

## Actual dependency graph

The real detectives form a clean DAG with no cycles:

~~~~
repo_url (project field)
  ├→ HowAccessRepoFilesDetective → repo_files
  │     ├→ RepoFilesExamineDetective → contribution_status, etc.
  │     ├→ SubdirFileContentsDetective → documentation_basics_status
  │     ├→ BuildDetective → build_status, etc.
  │     └→ BaselineDetective → osps_gv_02_01_status, etc.
  ├→ GithubBasicDetective → license, name, etc.
  │     ├→ FlossLicenseDetective → floss_license_*_status
  │     └→ BaselineDetective (also needs license)
  ├→ NameFromUrlDetective → name
  ├→ ProjectSitesHttpsDetective → sites_https_status
  └→ HardenedSitesDetective → hardened_site_status
~~~~

## Verdict

The implementation is correct and the recent bug fix was necessary and
properly applied. The only minor note is that sorted.include? and
no_dependencies.include? are O(n) array scans, making the algorithm O(V²)
rather than O(V+E), but with ~12 detectives this is completely negligible.
