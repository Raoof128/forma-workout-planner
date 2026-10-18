-- Run with the migration owner during the API upgrade (pause old API writers).
-- No member data leaves PostgreSQL. Re-running this migration changes no v2 row.
CREATE OR REPLACE FUNCTION pg_temp.forma_v2_set(original jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  result jsonb := '{"rpe":null,"legacyDraft":null}'::jsonb || original;
  field text;
  amount numeric;
  valid boolean;
BEGIN
  IF original ->> 'done' = 'false' THEN
    FOREACH field IN ARRAY ARRAY['weight','reps'] LOOP
      IF jsonb_typeof(original -> field) = 'number' THEN
        amount := (original ->> field)::numeric;
        valid := CASE WHEN field = 'weight' THEN amount >= 0 AND amount <= 1000
          ELSE amount >= 1 AND amount <= 100 AND amount = trunc(amount) END;
        IF NOT valid THEN
          result := jsonb_set(result,ARRAY[field],'""'::jsonb);
          result := jsonb_set(result,'{legacyDraft}',
            COALESCE(NULLIF(result -> 'legacyDraft','null'::jsonb),'{}'::jsonb) || jsonb_build_object(field,original ->> field));
        END IF;
      END IF;
    END LOOP;
  END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.forma_v2_entries(entries jsonb, is_session boolean)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  aliases constant jsonb := '{"wger-4b23738a-67a8-41af-996d-abc53a7c3f97":"db-incline-dumbbell-press","wger-e5e17c42-3c34-410b-84ab-81fde378778f":"db-incline-dumbbell-press","wger-57e17672-52b9-43cf-8d0d-4b3f06a0c0d0":"db-incline-dumbbell-press","wger-504230cb-4ac7-4b6c-b655-0800603081c1":"db-incline-dumbbell-press","db-incline-dumbbell-flyes":"wger-55ff32e6-24ab-4303-9b50-176d60d48796","wger-965eb23f-761c-45cd-bb7b-07d4d77040f1":"wger-55ff32e6-24ab-4303-9b50-176d60d48796"}'::jsonb;
  defaults constant jsonb := '{"repsMax":null,"rpe":null,"restSeconds":null,"perSide":false,"note":null,"groupId":null}'::jsonb;
  result jsonb := '[]'::jsonb;
  entry jsonb;
  original jsonb;
  target text;
  position integer := 0;
  collisions integer;
  has_alias boolean;
BEGIN
  FOR original IN SELECT value FROM jsonb_array_elements(entries) LOOP
    target := COALESCE(aliases ->> (original ->> 'exerciseId'), original ->> 'exerciseId');
    entry := defaults || original || jsonb_build_object('exerciseId',target);
    SELECT count(*), bool_or(aliases ? (value ->> 'exerciseId'))
      INTO collisions,has_alias FROM jsonb_array_elements(entries)
     WHERE COALESCE(aliases ->> (value ->> 'exerciseId'),value ->> 'exerciseId') = target;
    IF collisions > 1 AND has_alias AND NOT entry ? 'entryId' THEN
      entry := entry || jsonb_build_object('entryId','legacy-' || position || '-' || (original ->> 'exerciseId'));
    END IF;
    IF is_session THEN
      entry := jsonb_set(entry,'{sets}',COALESCE((SELECT jsonb_agg(pg_temp.forma_v2_set(value) ORDER BY ordinality)
        FROM jsonb_array_elements(entry -> 'sets') WITH ORDINALITY),'[]'::jsonb));
    END IF;
    result := result || jsonb_build_array(entry);
    position := position + 1;
  END LOOP;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.forma_v2_workspace(workspace jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  result jsonb := workspace;
  container text;
  owners jsonb;
  owner jsonb;
BEGIN
  FOREACH container IN ARRAY ARRAY['routines','history'] LOOP
    owners := '[]'::jsonb;
    FOR owner IN SELECT value FROM jsonb_array_elements(workspace -> container) LOOP
      owners := owners || jsonb_build_array(jsonb_set(owner,'{exercises}',pg_temp.forma_v2_entries(owner -> 'exercises',container = 'history')));
    END LOOP;
    result := jsonb_set(result,ARRAY[container],owners);
  END LOOP;
  IF jsonb_typeof(workspace -> 'active') = 'object' THEN
    result := jsonb_set(result,'{active,exercises}',pg_temp.forma_v2_entries(workspace #> '{active,exercises}',true));
  END IF;
  result := jsonb_set(result,'{profile}','{"restSeconds":90,"muted":false}'::jsonb || (workspace -> 'profile'));
  RETURN jsonb_set(result,'{version}','2'::jsonb);
END $$;

ALTER TABLE member_workspace DROP CONSTRAINT IF EXISTS member_workspace_data_version;
UPDATE member_workspace
   SET data = jsonb_set(pg_temp.forma_v2_workspace(data),'{revision}',to_jsonb(revision + 1)),
       revision = revision + 1,
       updated_at = GREATEST(clock_timestamp(),updated_at + interval '1 microsecond')
 WHERE data ->> 'version' = '1';
ALTER TABLE member_workspace ADD CONSTRAINT member_workspace_data_version CHECK (data ->> 'version' = '2');
DROP FUNCTION pg_temp.forma_v2_workspace(jsonb);
DROP FUNCTION pg_temp.forma_v2_entries(jsonb,boolean);
DROP FUNCTION pg_temp.forma_v2_set(jsonb);
