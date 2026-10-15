-- Avis clients : note, étiquettes, commande concernée et pseudo affiché.
ALTER TABLE "comments"
  ADD COLUMN "rating" INTEGER,
  ADD COLUMN "tags" JSONB,
  ADD COLUMN "orderId" INTEGER,
  ADD COLUMN "username" TEXT;

-- Un seul avis par client, par cible et par commande.
CREATE UNIQUE INDEX "comments_userId_target_targetId_orderId_key"
  ON "comments"("userId", "target", "targetId", "orderId");

CREATE INDEX "comments_orderId_idx" ON "comments"("orderId");
