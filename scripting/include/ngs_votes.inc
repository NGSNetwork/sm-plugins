#if defined _ngs_votes_included
 #endinput
#endif
#define _ngs_votes_included
#define _ngsvotes_version "0.0.3"

enum NGSVote_Type
{
    Regular,
    Randomized,
    Rotated
}

methodmap Vote < StringMap
{
    /**
     * Create a vote object to pass into start vote.
     *
     * @param type              Vote type to make resulting vote.
     * @param parameters        ArrayList of strings, where first should be question and rest are options.
     * @param max_size          Max size of string buffers.
     * @return                  New vote object to be used to StartSpecialVote.
     */
    public Vote(NGSVote_Type type, ArrayList parameters, int max_size)
    {
        char[] question = new char[max_size];
        StringMap map = new StringMap();
        map.SetValue("type", type);
        map.SetValue("size", max_size);
        parameters.GetString(0, question, max_size);
        parameters.Erase(0);
        map.SetString("question", question);
        map.SetValue(parameters);
        return view_as<Vote>(map);
    }
}

/**
 * Called when a timed randomized vote is finished.
 */
forward void OnSpecialVoteFinished(Vote vote);

native bool StartSpecialVote(Vote vote);