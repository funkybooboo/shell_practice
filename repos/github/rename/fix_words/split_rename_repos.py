import re

# Function to load the dictionary from file
def load_dictionary(filename="dictionary.txt"):
    with open(filename, "r") as file:
        # Read each line and remove any extra spaces/newlines
        dictionary = [line.strip().lower() for line in file.readlines()]
    return dictionary

# Function to split repository name into dictionary words
def split_repo_name(repo_name, dictionary):
    result = []
    temp_name = repo_name.lower()  # Convert to lowercase for case-insensitive matching
    while temp_name:
        matched = False
        # Try matching the longest possible word from the start of the string
        for word in dictionary:
            if temp_name.startswith(word):
                result.append(word)  # If a match, add the word to result
                temp_name = temp_name[len(word):]  # Remove matched part from temp_name
                matched = True
                break  # Break the loop as we've found a match
        if not matched:
            # If no match is found, return an error
            print(f"Failed to match part of '{repo_name}'. Remaining string: '{temp_name}'")
            return None
    return "_".join(result)

# Function to process repositories and generate renamed_repos.txt
def main():
    # Load the dictionary from file
    dictionary = load_dictionary()

    # Read the list of repository names from repos.txt
    with open("repos.txt", "r") as file:
        repo_names = [line.strip() for line in file.readlines()]

    renamed_repos = []

    # Iterate through each repo name, apply the split logic and prepare old-new pairs
    for repo_name in repo_names:
        new_repo_name = split_repo_name(repo_name, dictionary)
        if new_repo_name:
            renamed_repos.append(f"{repo_name},{new_repo_name}")
            print(f"Repository '{repo_name}' will be renamed to '{new_repo_name}'.")
        else:
            print(f"Failed to process '{repo_name}'.")

    # Write the old and new names to renamed_repos.txt
    with open("renamed_repos.txt", "w") as file:
        for line in renamed_repos:
            file.write(f"{line}\n")

    print("Renamed repository list has been saved to renamed_repos.txt.")

if __name__ == "__main__":
    main()

