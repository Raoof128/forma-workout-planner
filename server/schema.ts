import { z } from "zod";
import { dataSchema, validateData } from "../src/storage.js";

// Keep the API contract tied to the same schema that validates browser backups.
// The API rejects unknown fields at every level; ownership comes from the session.
export { dataSchema };

// dataSchema handles the serialized shape. validateData also enforces the
// cross-field invariant that the active session cannot already be in history.
export const workspaceDataSchema = z.unknown().transform((value, context) => {
  try {
    return validateData(value, { strict: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      for (const issue of error.issues) {
        context.addIssue({
          code: "custom",
          message: issue.message,
          path: issue.path,
        });
      }
    } else {
      context.addIssue({
        code: "custom",
        message: "The active workout is already present in history.",
      });
    }
    return z.NEVER;
  }
});
export type WorkspaceData = z.infer<typeof dataSchema>;

export const workspacePutSchema = z
  .object({
    data: workspaceDataSchema,
    expectedRevision: z.number().int().min(0).max(2_147_483_647),
    operationId: z.string().trim().min(1).max(200),
  })
  .strict();

export type WorkspaceAcknowledgement = {
  data: WorkspaceData;
  revision: number;
  updatedAt: string;
};

// A coach edit names whole sections to replace; the merged result is checked
// with workspaceDataSchema. Unknown sections (revision, version) are refused.
export const coachPatchSchema = z
  .object({
    expectedRevision: z.number().int().min(0).max(2_147_483_647),
    operationId: z.string().trim().min(1).max(200),
    changes: z
      .object({
        routines: z.unknown().optional(),
        history: z.unknown().optional(),
        active: z.unknown().optional(),
        profile: z.unknown().optional(),
        schedule: z.unknown().optional(),
      })
      .strict()
      .refine(
        (changes) => Object.keys(changes).length > 0,
        "Name at least one section to change.",
      ),
    removesSessions: z.number().int().min(1).max(10_000).optional(),
  })
  .strict();
